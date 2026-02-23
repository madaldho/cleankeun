//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class ToolkitService {
    static let shared = ToolkitService()

    let cachedMacOSVersion: String
    let cachedMachineModel: String

    private init() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        self.cachedMacOSVersion = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        self.cachedMachineModel = String(cString: model)
    }

    // MARK: - Async Process Helper (BUG-07, BUG-36)
    /// Runs a subprocess off the main thread using `DispatchQueue.global(qos: .userInitiated)`.
    ///
    /// **Why DispatchQueue.global instead of structured concurrency?**
    /// `Process.run()` + `waitUntilExit()` are blocking synchronous calls that can take
    /// an arbitrary amount of time (e.g., Spotlight reindexing, admin password prompts).
    /// Swift concurrency tasks should never block their executor thread — doing so can
    /// exhaust the cooperative thread pool and cause deadlocks. By dispatching to a GCD
    /// queue, we isolate the blocking work from the Swift concurrency runtime.
    ///
    /// The `withCheckedContinuation` bridges the GCD callback back into structured
    /// concurrency so callers can `await` the result safely.
    ///
    /// Reads stderr for error messages. Uses nullDevice for stdout to prevent pipe buffer
    /// deadlocks (BUG-36). When `requiresRoot` is true, uses osascript to prompt for
    /// admin password.
    private func runProcess(
        executableURL: URL,
        arguments: [String],
        requiresRoot: Bool = false,
        timeout: TimeInterval = 60.0
    ) async -> (success: Bool, exitCode: Int32, errorOutput: String) {
        await withCheckedContinuation { continuation in
            var continuationConsumed = false
            let lock = NSLock()
            
            let workItem = DispatchWorkItem {
                let process = Process()

                if requiresRoot {
                    // Build the shell command string with proper escaping
                    let cmdParts = [executableURL.path] + arguments
                    let safeCmdParts = cmdParts.map { SecurityHelpers.sanitizeForShell($0) }
                    let escapedCmd = safeCmdParts.joined(separator: " ")
                    let scriptStr = "do shell script \"\(SecurityHelpers.sanitizeForAppleScript(escapedCmd))\" with administrator privileges"
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", scriptStr]
                } else {
                    process.executableURL = executableURL
                    process.arguments = arguments
                }

                process.standardOutput = FileHandle.nullDevice
                let errorPipe = Pipe()
                process.standardError = errorPipe

                // Set up a termination handler for the timeout
                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                timer.resume()

                do {
                    try process.run()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timer.cancel()
                    
                    let errorString = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let success = process.terminationStatus == 0
                    
                    lock.lock()
                    if !continuationConsumed {
                        continuationConsumed = true
                        continuation.resume(returning: (success, process.terminationStatus, errorString))
                    }
                    lock.unlock()
                } catch {
                    timer.cancel()
                    lock.lock()
                    if !continuationConsumed {
                        continuationConsumed = true
                        continuation.resume(returning: (false, -1, error.localizedDescription))
                    }
                    lock.unlock()
                }
            }
            
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    // MARK: - Flush DNS Cache
    func flushDNS() async -> (success: Bool, message: String) {
        // BUG-20: dscacheutil doesn't require root, but killall -HUP mDNSResponder may need it
        let result1 = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/dscacheutil"),
            arguments: ["-flushcache"]
        )

        let result2 = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/killall"),
            arguments: ["-HUP", "mDNSResponder"]
        )

        if result1.success && result2.success {
            return (true, "DNS cache flushed successfully")
        } else if result1.success {
            return (true, "DNS cache flushed (mDNSResponder restart may require admin privileges)")
        } else {
            return (false, "Failed to flush DNS: \(result1.errorOutput)")
        }
    }

    // MARK: - Rebuild Spotlight Index
    func rebuildSpotlight() async -> (success: Bool, message: String) {
        let result = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/mdutil"),
            arguments: ["-E", "/"],
            requiresRoot: true
        )

        if result.success {
            return (true, "Spotlight reindexing started. This may take a while.")
        } else if result.errorOutput.contains("User canceled") || result.exitCode == 1 && result.errorOutput.isEmpty {
            return (false, "Administrator authentication was cancelled.")
        } else {
            return (
                false,
                "Failed to rebuild Spotlight (exit code \(result.exitCode)): \(result.errorOutput)"
            )
        }
    }

    // MARK: - Rebuild Launch Services
    func rebuildLaunchServices() async -> (success: Bool, message: String) {
        let lsRegisterPath =
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        let result = await runProcess(
            executableURL: URL(fileURLWithPath: lsRegisterPath),
            arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        )

        if result.success {
            return (true, "Launch Services database rebuilt successfully")
        } else {
            return (
                false,
                "Failed to rebuild Launch Services (exit code \(result.exitCode)): \(result.errorOutput)"
            )
        }
    }

    // MARK: - Trash Info
    /// Returns trash item count, total size, and whether access was denied.
    /// `accessDenied` = true means the app doesn't have Full Disk Access permission.
    func getTrashInfo() -> (itemCount: Int, totalSize: Int64, accessDenied: Bool) {
        let fm = FileManager.default
        var totalItems = 0
        var totalSize: Int64 = 0
        var accessDenied = false

        // 1. User trash: ~/.Trash
        let userTrash = "\(NSHomeDirectory())/.Trash"
        do {
            let items = try fm.contentsOfDirectory(atPath: userTrash)
            // Filter out only .DS_Store and .localized (macOS metadata), keep everything else
            let realItems = items.filter { $0 != ".DS_Store" && $0 != ".localized" }
            totalItems += realItems.count
            for item in realItems {
                let fullPath = (userTrash as NSString).appendingPathComponent(item)
                totalSize += sizeOfItem(atPath: fullPath, fm: fm)
            }
        } catch {
            // "Operation not permitted" = app doesn't have Full Disk Access
            if (error as NSError).code == NSFileReadNoPermissionError
                || error.localizedDescription.contains("Operation not permitted")
                || (error as NSError).code == 257 {
                accessDenied = true
            }
        }

        // 2. Volume trashes: /Volumes/<name>/.Trashes/<uid>/
        let uid = getuid()
        if let volumes = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for vol in volumes {
                let trashPath = "/Volumes/\(vol)/.Trashes/\(uid)"
                do {
                    let items = try fm.contentsOfDirectory(atPath: trashPath)
                    let realItems = items.filter { $0 != ".DS_Store" && $0 != ".localized" }
                    totalItems += realItems.count
                    for item in realItems {
                        let fullPath = (trashPath as NSString).appendingPathComponent(item)
                        totalSize += sizeOfItem(atPath: fullPath, fm: fm)
                    }
                } catch {
                    // Volume trash might also be inaccessible
                }
            }
        }

        return (totalItems, totalSize, accessDenied)
    }

    private func sizeOfItem(atPath path: String, fm: FileManager) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            var total: Int64 = 0
            if let enumerator = fm.enumerator(atPath: path) {
                for case let file as String in enumerator {
                    let fullPath = (path as NSString).appendingPathComponent(file)
                    if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64 {
                        total += size
                    }
                }
            }
            return total
        } else {
            let attrs = try? fm.attributesOfItem(atPath: path)
            return (attrs?[.size] as? Int64) ?? 0
        }
    }

    // MARK: - Empty Trash
    /// Empties the Trash using Finder via AppleScript.
    /// This bypasses Full Disk Access requirements because Finder always has
    /// permission to manage the Trash. The user will see Finder's own confirmation
    /// dialog if they have that enabled in Finder preferences.
    func emptyTrash() async -> (success: Bool, message: String) {
        // First check if we can even read trash (to report accurate status)
        let info = getTrashInfo()

        if !info.accessDenied && info.itemCount == 0 {
            return (true, "Trash is already empty")
        }

        // Use Finder via AppleScript — this always works regardless of FDA
        let script = "tell application \"Finder\" to empty trash"
        let result = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", script]
        )

        if result.success {
            let sizeStr = ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file)
            if info.accessDenied {
                return (true, "Trash emptied via Finder")
            } else {
                return (true, "Trash emptied — \(info.itemCount) items removed (\(sizeStr) freed)")
            }
        } else if result.errorOutput.contains("User canceled") || result.errorOutput.contains("cancelled") {
            return (false, "Operation cancelled by user")
        } else {
            return (false, "Failed to empty trash: \(result.errorOutput)")
        }
    }

    // MARK: - Free Purgeable Disk Space
    /// Frees purgeable disk space by creating a massive dummy file to force macOS to reclaim space,
    /// and then deleting the dummy file. This mimics BuhoCleaner's approach.
    func freePurgeableSpace(progressCallback: @escaping (Double, String) -> Void) async -> (success: Bool, message: String) {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        
        do {
            // 1. Cek ukuran sebelum dibersihkan
            let initialValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let initialAvailable = Int64(initialValues.volumeAvailableCapacityForImportantUsage ?? 0)
            
            progressCallback(0.3, "Thinning APFS local snapshots...")
            
            // 2. Jalankan perintah Terminal bawaan macOS secara instan (tanpa membuat file sampah)
            // Command: tmutil thinlocalsnapshots / 1000000000000 4
            // (Meminta macOS untuk mengosongkan snapshot hingga 1TB dengan prioritas/urgensi tertinggi '4')
            let _ = await runProcess(
                executableURL: URL(fileURLWithPath: "/usr/bin/tmutil"),
                arguments: ["thinlocalsnapshots", "/", "1000000000000", "4"],
                requiresRoot: false
            )
            
            progressCallback(0.8, "Calculating freed space...")
            
            // Beri jeda 1 detik agar sistem file APFS macOS memperbarui status penyimpanannya
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // 3. Cek ukuran setelah dibersihkan
            let finalValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let finalAvailable = Int64(finalValues.volumeAvailableCapacityForImportantUsage ?? 0)
            
            let freed = finalAvailable - initialAvailable
            progressCallback(1.0, "Reclamation complete")
            
            if freed > 0 {
                let freedStr = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
                return (true, "Successfully reclaimed \(freedStr) of purgeable space")
            } else {
                return (true, "Reclamation complete, but no new purgeable space was freed.")
            }
            
        } catch {
            return (false, "Failed to reclaim purgeable space: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear Browser Data (Safari & Chrome caches)
    func clearBrowserData() async -> (success: Bool, message: String) {
        let fm = FileManager.default
        var freedBytes: Int64 = 0
        var cleared: [String] = []
        var errors: [String] = []

        // Safari caches
        let safariPaths = [
            "\(NSHomeDirectory())/Library/Caches/com.apple.Safari",
            "\(NSHomeDirectory())/Library/Caches/com.apple.Safari.SafeBrowsing",
            "\(NSHomeDirectory())/Library/Safari/LocalStorage",
        ]
        var safariFreed: Int64 = 0
        for path in safariPaths {
            let (freed, err) = clearDirectory(path, fm: fm)
            safariFreed += freed
            if let err = err { errors.append(err) }
        }
        if safariFreed > 0 {
            cleared.append("Safari \(ByteCountFormatter.string(fromByteCount: safariFreed, countStyle: .file))")
            freedBytes += safariFreed
        }

        // Chrome caches
        let chromePaths = [
            "\(NSHomeDirectory())/Library/Caches/Google/Chrome/Default/Cache",
            "\(NSHomeDirectory())/Library/Caches/Google/Chrome/Default/Code Cache",
            "\(NSHomeDirectory())/Library/Caches/Google/Chrome/Default/Service Worker/CacheStorage",
        ]
        var chromeFreed: Int64 = 0
        for path in chromePaths {
            let (freed, err) = clearDirectory(path, fm: fm)
            chromeFreed += freed
            if let err = err { errors.append(err) }
        }
        if chromeFreed > 0 {
            cleared.append("Chrome \(ByteCountFormatter.string(fromByteCount: chromeFreed, countStyle: .file))")
            freedBytes += chromeFreed
        }

        // Firefox caches
        let firefoxCacheBase = "\(NSHomeDirectory())/Library/Caches/Firefox/Profiles"
        if fm.fileExists(atPath: firefoxCacheBase),
           let profiles = try? fm.contentsOfDirectory(atPath: firefoxCacheBase) {
            var ffFreed: Int64 = 0
            for profile in profiles {
                let cachePath = (firefoxCacheBase as NSString).appendingPathComponent(profile)
                let cache2 = (cachePath as NSString).appendingPathComponent("cache2")
                let (freed, _) = clearDirectory(cache2, fm: fm)
                ffFreed += freed
            }
            if ffFreed > 0 {
                cleared.append("Firefox \(ByteCountFormatter.string(fromByteCount: ffFreed, countStyle: .file))")
                freedBytes += ffFreed
            }
        }

        // Arc caches
        let arcPaths = [
            "\(NSHomeDirectory())/Library/Caches/company.thebrowser.Browser",
        ]
        var arcFreed: Int64 = 0
        for path in arcPaths {
            let (freed, _) = clearDirectory(path, fm: fm)
            arcFreed += freed
        }
        if arcFreed > 0 {
            cleared.append("Arc \(ByteCountFormatter.string(fromByteCount: arcFreed, countStyle: .file))")
            freedBytes += arcFreed
        }

        if cleared.isEmpty && errors.isEmpty {
            return (true, "No browser cache found to clear")
        } else if freedBytes > 0 {
            let total = ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
            return (true, "Cleared \(total): \(cleared.joined(separator: ", "))")
        } else {
            return (false, "Could not clear caches: \(errors.joined(separator: "; "))")
        }
    }

    private func clearDirectory(_ path: String, fm: FileManager) -> (freed: Int64, error: String?) {
        guard fm.fileExists(atPath: path) else { return (0, nil) }
        var freed: Int64 = 0
        guard let items = try? fm.contentsOfDirectory(atPath: path) else {
            return (0, "Cannot read \(path)")
        }
        for item in items {
            let fullPath = (path as NSString).appendingPathComponent(item)
            let size = sizeOfItem(atPath: fullPath, fm: fm)
            do {
                try fm.removeItem(atPath: fullPath)
                freed += size
            } catch {
                // Skip items that can't be deleted (in use, etc.)
            }
        }
        return (freed, nil)
    }

    // MARK: - System Uptime
    func getSystemUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let mins = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    // MARK: - macOS Version
    func getMacOSVersion() -> String {
        return cachedMacOSVersion
    }

    // MARK: - Machine Model
    func getMachineModel() -> String {
        return cachedMachineModel
    }
}
