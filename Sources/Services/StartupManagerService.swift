//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class StartupManagerService {
    static let shared = StartupManagerService()
    private let fileManager = FileManager.default

    func scanStartupItems() -> [StartupItem] {
        var items: [StartupItem] = []
        let home = NSHomeDirectory()
        items.append(contentsOf: scanLaunchDir(path: "\(home)/Library/LaunchAgents", type: .launchAgent))
        items.append(contentsOf: scanLaunchDir(path: "/Library/LaunchAgents", type: .launchAgent))
        items.append(contentsOf: scanLaunchDir(path: "/Library/LaunchDaemons", type: .launchDaemon))
        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func scanLaunchDir(path: String, type: StartupType) -> [StartupItem] {
        var items: [StartupItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return items }
        for file in contents where file.hasSuffix(".plist") {
            let fullPath = (path as NSString).appendingPathComponent(file)
            guard let data = fileManager.contents(atPath: fullPath),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
            let label = plist["Label"] as? String ?? (file as NSString).deletingPathExtension
            let disabled = plist["Disabled"] as? Bool ?? false
            items.append(StartupItem(name: label, path: fullPath, type: type, isEnabled: !disabled, bundleIdentifier: plist["Label"] as? String))
        }
        return items
    }

    // BUG-08: Move process.waitUntilExit() off main thread
    // BUG-18: Check write permissions before attempting to modify plist
    func toggleStartupItem(_ item: StartupItem) async -> Bool {
        // BUG-18: Check if we can write to the plist file
        guard fileManager.isWritableFile(atPath: item.path) else {
            // System/global plists in /Library/LaunchDaemons require root
            return false
        }

        guard let data = fileManager.contents(atPath: item.path),
              var plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        plist["Disabled"] = item.isEnabled
        do {
            let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try newData.write(to: URL(fileURLWithPath: item.path))

            // BUG-08: Run launchctl off the main thread
            let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                    process.arguments = item.isEnabled ? ["unload", "-w", item.path] : ["load", "-w", item.path]
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                    do {
                        try process.run()
                        process.waitUntilExit()
                        continuation.resume(returning: process.terminationStatus == 0)
                    } catch {
                        continuation.resume(returning: false)
                    }
                }
            }
            return success
        } catch { return false }
    }
}
