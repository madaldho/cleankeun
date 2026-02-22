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
    /// Runs a process off the main thread and reads stderr for error messages.
    /// Uses nullDevice for stdout to prevent pipe buffer deadlocks (BUG-36).
    private func runProcess(
        executableURL: URL,
        arguments: [String],
        requiresRoot: Bool = false
    ) async -> (success: Bool, exitCode: Int32, errorOutput: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
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
        // BUG-22: mdutil -E / requires root
        let result = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/mdutil"),
            arguments: ["-E", "/"],
            requiresRoot: true
        )

        if result.success {
            return (true, "Spotlight reindexing started. This may take a while.")
        } else if result.exitCode == 1 {
            return (
                false,
                "Spotlight rebuild requires administrator privileges. Run Cleankeun with sudo or grant Full Disk Access."
            )
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

    // MARK: - Empty Trash Securely
    func emptyTrash() async -> (success: Bool, message: String) {
        let trashPath = "\(NSHomeDirectory())/.Trash"
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: trashPath) else {
            return (false, "Cannot access Trash")
        }

        var errors = 0
        for item in items {
            let fullPath = (trashPath as NSString).appendingPathComponent(item)
            do {
                try fm.removeItem(atPath: fullPath)
            } catch {
                errors += 1
            }
        }

        if errors == 0 {
            return (true, "Trash emptied (\(items.count) items removed)")
        } else {
            return (true, "Removed \(items.count - errors) items, \(errors) failed")
        }
    }

    // MARK: - Free Purgeable Disk Space
    func freePurgeableSpace() async -> (success: Bool, message: String) {
        // BUG-23: diskutil apfs defragment requires root
        let result = await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/sbin/diskutil"),
            arguments: ["apfs", "defragment", "/", "live"],
            requiresRoot: true
        )

        if result.success {
            return (true, "Purgeable space freed")
        } else if result.exitCode == 1 {
            return (false, "Freeing purgeable space requires administrator privileges.")
        } else {
            return (
                false,
                "Failed to free purgeable space (exit code \(result.exitCode)): \(result.errorOutput)"
            )
        }
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
