//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class ToolkitService {
    static let shared = ToolkitService()

    // Cached values — these never change during app runtime
    lazy var cachedMacOSVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }()

    lazy var cachedMachineModel: String = {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }()

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
        requiresRoot: Bool = false
    ) async -> (success: Bool, exitCode: Int32, errorOutput: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()

                if requiresRoot {
                    // Build the shell command string with proper escaping
                    let cmdParts = [executableURL.path] + arguments
                    let escapedCmd = cmdParts.map { arg in
                        // Escape single quotes for AppleScript string
                        arg.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
                    }.joined(separator: " ")
                    let script = "do shell script \"\(escapedCmd)\" with administrator privileges"
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                } else {
                    process.executableURL = executableURL
                    process.arguments = arguments
                }

                process.standardOutput = FileHandle.nullDevice
                let errorPipe = Pipe()
                process.standardError = errorPipe

                do {
                    try process.run()
                    // Read stderr BEFORE waitUntilExit to avoid pipe buffer deadlock.
                    // If the subprocess writes > 64KB to stderr while we're blocked on
                    // waitUntilExit, both sides will deadlock.
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    continuation.resume(
                        returning: (
                            process.terminationStatus == 0, process.terminationStatus, errorOutput
                        ))
                } catch {
                    continuation.resume(returning: (false, -1, error.localizedDescription))
                }
            }
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
    func getTrashInfo() -> (itemCount: Int, totalSize: Int64) {
        let fm = FileManager.default
        var totalItems = 0
        var totalSize: Int64 = 0

        // 1. User trash: ~/.Trash
        let userTrash = "\(NSHomeDirectory())/.Trash"
        if let items = try? fm.contentsOfDirectory(atPath: userTrash) {
            totalItems += items.count
            for item in items {
                let fullPath = (userTrash as NSString).appendingPathComponent(item)
                totalSize += sizeOfItem(atPath: fullPath, fm: fm)
            }
        }

        // 2. Volume trashes: /Volumes/<name>/.Trashes/<uid>/
        let uid = getuid()
        if let volumes = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for vol in volumes {
                let trashPath = "/Volumes/\(vol)/.Trashes/\(uid)"
                if let items = try? fm.contentsOfDirectory(atPath: trashPath) {
                    totalItems += items.count
                    for item in items {
                        let fullPath = (trashPath as NSString).appendingPathComponent(item)
                        totalSize += sizeOfItem(atPath: fullPath, fm: fm)
                    }
                }
            }
        }

        return (totalItems, totalSize)
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

    // MARK: - Empty Trash Securely
    func emptyTrash() async -> (success: Bool, message: String) {
        let fm = FileManager.default
        var totalDeleted = 0
        var errors = 0

        // Helper to clean a trash directory
        func cleanTrashDir(_ path: String) {
            guard let items = try? fm.contentsOfDirectory(atPath: path) else { return }
            for item in items {
                let fullPath = (path as NSString).appendingPathComponent(item)
                do {
                    try fm.removeItem(atPath: fullPath)
                    totalDeleted += 1
                } catch {
                    errors += 1
                }
            }
        }

        // 1. User trash
        cleanTrashDir("\(NSHomeDirectory())/.Trash")

        // 2. Volume trashes
        let uid = getuid()
        if let volumes = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for vol in volumes {
                cleanTrashDir("/Volumes/\(vol)/.Trashes/\(uid)")
            }
        }

        if totalDeleted == 0 && errors == 0 {
            return (true, "Trash is already empty")
        } else if errors == 0 {
            return (true, "Trash emptied (\(totalDeleted) items removed)")
        } else {
            return (true, "Removed \(totalDeleted) items, \(errors) failed (may need permissions)")
        }
    }

    // MARK: - Free Purgeable Disk Space
    func freePurgeableSpace() async -> (success: Bool, message: String) {
        let result = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["apfs", "defragment", "/", "live"],
            requiresRoot: true
        )

        if result.success {
            return (true, "Purgeable space freed")
        } else if result.errorOutput.contains("User canceled") || result.exitCode == 1 && result.errorOutput.isEmpty {
            return (false, "Administrator authentication was cancelled.")
        } else {
            return (
                false,
                "Failed to free purgeable space (exit code \(result.exitCode)): \(result.errorOutput)"
            )
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
