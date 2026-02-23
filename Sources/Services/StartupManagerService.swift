//
//  Cleankeun — macOS System Cleaner & Optimizer
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

        // 1. Scan Launch Agents & Daemons (plist-based)
        items.append(contentsOf: scanLaunchDir(path: "\(home)/Library/LaunchAgents", type: .launchAgent))
        items.append(contentsOf: scanLaunchDir(path: "/Library/LaunchAgents", type: .launchAgent))
        items.append(contentsOf: scanLaunchDir(path: "/Library/LaunchDaemons", type: .launchDaemon))

        // 2. Scan Login Items (apps that open on login)
        items.append(contentsOf: scanLoginItems())

        // Deduplicate by path (some login items may also appear as launch agents)
        var seen = Set<String>()
        items = items.filter { item in
            let key = item.path.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - Login Items Detection

    /// Detects Login Items using multiple methods for comprehensive coverage:
    /// 1. backgrounditems.btm (Background Task Management agent database)
    /// 2. System Events via osascript (legacy AppleScript approach)
    /// 3. SMAppService-registered apps in known locations
    private func scanLoginItems() -> [StartupItem] {
        var items: [StartupItem] = []
        var seenPaths = Set<String>()

        // Method 1: Read backgrounditems.btm (works on macOS 13+)
        let btmPaths = [
            "\(NSHomeDirectory())/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm",
        ]

        for btmPath in btmPaths {
            if let btmItems = readBackgroundTaskItems(path: btmPath) {
                for item in btmItems where !seenPaths.contains(item.path.lowercased()) {
                    seenPaths.insert(item.path.lowercased())
                    items.append(item)
                }
            }
        }

        // Method 2: Query System Events for Login Items via osascript
        let osaItems = queryLoginItemsViaOSAScript()
        for item in osaItems where !seenPaths.contains(item.path.lowercased()) {
            seenPaths.insert(item.path.lowercased())
            items.append(item)
        }

        // Method 3: Check common Login Items locations
        let loginItemsPaths = [
            "\(NSHomeDirectory())/Library/Application Support/com.apple.backgroundtaskmanagementagent",
        ]
        for basePath in loginItemsPaths {
            if let contents = try? fileManager.contentsOfDirectory(atPath: basePath) {
                for file in contents where file.hasSuffix(".plist") && file != "backgrounditems.btm" {
                    let fullPath = (basePath as NSString).appendingPathComponent(file)
                    if !seenPaths.contains(fullPath.lowercased()) {
                        seenPaths.insert(fullPath.lowercased())
                        let label = (file as NSString).deletingPathExtension
                        items.append(StartupItem(
                            name: label,
                            path: fullPath,
                            type: .loginItem,
                            isEnabled: true,
                            bundleIdentifier: nil
                        ))
                    }
                }
            }
        }

        // Method 4: Scan for apps with Login Items registered via SMAppService
        // Check apps in /Applications that have a LoginItems target in their bundle
        items.append(contentsOf: scanBundleLoginItems(seenPaths: &seenPaths))

        return items
    }

    /// Read the Background Task Management agent's BTM database.
    /// This file contains apps registered to launch on login via SMAppService or legacy APIs.
    private func readBackgroundTaskItems(path: String) -> [StartupItem]? {
        guard let data = fileManager.contents(atPath: path) else { return nil }

        // Try to decode as a binary plist / NSKeyedArchiver
        // The BTM file is an NSKeyedArchiver archive containing login items
        guard let obj = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [
            NSArray.self, NSDictionary.self, NSString.self, NSNumber.self, NSURL.self, NSData.self, NSDate.self
        ], from: data) else {
            // Fallback: try regular plist
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
                return nil
            }
            return extractLoginItemsFromPlist(plist)
        }

        return extractLoginItemsFromArchive(obj)
    }

    private func extractLoginItemsFromPlist(_ plist: Any) -> [StartupItem] {
        var items: [StartupItem] = []

        if let dict = plist as? [String: Any] {
            // Look for various keys that contain login items
            let possibleKeys = ["backgroundItems", "items", "loginItems", "$objects"]
            for key in possibleKeys {
                if let arr = dict[key] as? [[String: Any]] {
                    for entry in arr {
                        if let item = loginItemFromDict(entry) {
                            items.append(item)
                        }
                    }
                }
            }
        } else if let arr = plist as? [[String: Any]] {
            for entry in arr {
                if let item = loginItemFromDict(entry) {
                    items.append(item)
                }
            }
        }

        return items
    }

    private func extractLoginItemsFromArchive(_ obj: Any) -> [StartupItem] {
        var items: [StartupItem] = []

        if let dict = obj as? NSDictionary {
            // The root object may contain arrays of items
            for (_, value) in dict {
                if let arr = value as? NSArray {
                    for element in arr {
                        if let itemDict = element as? NSDictionary {
                            if let item = loginItemFromNSDict(itemDict) {
                                items.append(item)
                            }
                        }
                    }
                }
            }
        } else if let arr = obj as? NSArray {
            for element in arr {
                if let itemDict = element as? NSDictionary {
                    if let item = loginItemFromNSDict(itemDict) {
                        items.append(item)
                    }
                }
            }
        }

        return items
    }

    private func loginItemFromDict(_ dict: [String: Any]) -> StartupItem? {
        var name = dict["Name"] as? String
            ?? dict["name"] as? String
            ?? dict["Label"] as? String
        var path = dict["URL"] as? String
            ?? dict["Path"] as? String
            ?? dict["path"] as? String
            ?? ""
        let bundleId = dict["BundleIdentifier"] as? String
            ?? dict["bundleIdentifier"] as? String
            ?? dict["Identifier"] as? String

        // Handle file:// URLs
        if path.hasPrefix("file://") {
            path = URL(string: path)?.path ?? path
        }

        if name == nil && !path.isEmpty {
            name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        if name == nil { name = bundleId }

        guard let finalName = name, !finalName.isEmpty else { return nil }

        let disabled = dict["Disabled"] as? Bool
            ?? dict["disabled"] as? Bool
            ?? false

        return StartupItem(
            name: finalName,
            path: path.isEmpty ? (bundleId ?? "Unknown") : path,
            type: .loginItem,
            isEnabled: !disabled,
            bundleIdentifier: bundleId
        )
    }

    private func loginItemFromNSDict(_ dict: NSDictionary) -> StartupItem? {
        var swift: [String: Any] = [:]
        for (key, value) in dict {
            if let k = key as? String {
                swift[k] = value
            }
        }
        return loginItemFromDict(swift)
    }

    /// Query Login Items via AppleScript / System Events.
    /// This is a fallback for older macOS versions or when BTM is unavailable.
    private func queryLoginItemsViaOSAScript() -> [StartupItem] {
        let script = """
        tell application "System Events"
            set loginList to {}
            try
                set loginItems to every login item
                repeat with li in loginItems
                    set itemName to name of li
                    set itemPath to path of li
                    set isHidden to hidden of li
                    set end of loginList to {itemName, itemPath, isHidden}
                end repeat
            end try
        end tell
        return loginList
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return []
            }

            return parseOSAScriptLoginItems(output)
        } catch {
            return []
        }
    }

    private func parseOSAScriptLoginItems(_ output: String) -> [StartupItem] {
        // osascript returns items as: name, path, hidden, name, path, hidden, ...
        var items: [StartupItem] = []
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // The output format varies; try to split by comma and group by 3
        let components = trimmed.components(separatedBy: ", ")
        var i = 0
        while i + 2 < components.count {
            let name = components[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let path = components[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            // hidden is components[i+2], but we don't use it for isEnabled (login items are always enabled if listed)

            if !name.isEmpty && !path.isEmpty {
                // Resolve bundle identifier from the app path
                let bundleId = Bundle(path: path)?.bundleIdentifier

                items.append(StartupItem(
                    name: name,
                    path: path,
                    type: .loginItem,
                    isEnabled: true,
                    bundleIdentifier: bundleId
                ))
            }
            i += 3
        }

        return items
    }

    /// Scan /Applications for apps that have login helper bundles.
    /// Many apps register Login Items by embedding a helper app in their LoginItems folder.
    private func scanBundleLoginItems(seenPaths: inout Set<String>) -> [StartupItem] {
        var items: [StartupItem] = []

        let searchPaths = [
            "/Applications",
            "\(NSHomeDirectory())/Applications",
        ]

        for basePath in searchPaths {
            guard let apps = try? fileManager.contentsOfDirectory(atPath: basePath) else { continue }
            for app in apps where app.hasSuffix(".app") {
                let appPath = (basePath as NSString).appendingPathComponent(app)
                let loginItemsPath = "\(appPath)/Contents/Library/LoginItems"

                guard fileManager.fileExists(atPath: loginItemsPath) else { continue }
                guard let helpers = try? fileManager.contentsOfDirectory(atPath: loginItemsPath) else { continue }

                for helper in helpers where helper.hasSuffix(".app") {
                    let helperPath = (loginItemsPath as NSString).appendingPathComponent(helper)
                    let key = helperPath.lowercased()
                    guard !seenPaths.contains(key) else { continue }
                    seenPaths.insert(key)

                    let helperBundle = Bundle(path: helperPath)
                    let appName = (app as NSString).deletingPathExtension
                    let helperName = (helper as NSString).deletingPathExtension

                    // Use the parent app name for clarity
                    let displayName = helperName.contains(appName) ? appName : "\(appName) (\(helperName))"

                    items.append(StartupItem(
                        name: displayName,
                        path: helperPath,
                        type: .loginItem,
                        isEnabled: true,  // Can't easily determine state for embedded helpers
                        bundleIdentifier: helperBundle?.bundleIdentifier
                    ))
                }
            }
        }

        return items
    }

    // MARK: - Launch Agent/Daemon Scanning

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

    // MARK: - Toggle

    // BUG-08: Move process.waitUntilExit() off main thread
    // BUG-18: Check write permissions before attempting to modify plist
    func toggleStartupItem(_ item: StartupItem) async -> Bool {
        // For Login Items (apps), use a different approach
        if item.type == .loginItem {
            return await toggleLoginItem(item)
        }

        guard let data = fileManager.contents(atPath: item.path),
              var plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        plist["Disabled"] = item.isEnabled

        let needsEscalation = !fileManager.isWritableFile(atPath: item.path)

        if needsEscalation {
            // System plist — use osascript for admin privilege escalation
            return await escalatedToggle(item: item, newDisabledValue: item.isEnabled)
        }

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

    /// Toggle a Login Item — opens System Settings to the Login Items page
    /// since programmatic toggling of login items requires SMAppService and a known bundle ID.
    private func toggleLoginItem(_ item: StartupItem) async -> Bool {
        // If it's a login item registered through System Events, try to toggle via osascript
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                if item.isEnabled {
                    // Remove login item
                    let safeName = SecurityHelpers.sanitizeForAppleScript(item.name)
                    let script = """
                    tell application "System Events"
                        try
                            delete login item "\(safeName)"
                            return "ok"
                        on error
                            return "fail"
                        end try
                    end tell
                    """
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = FileHandle.nullDevice
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        continuation.resume(returning: output == "ok" || process.terminationStatus == 0)
                    } catch {
                        continuation.resume(returning: false)
                    }
                } else {
                    // Add login item back
                    let itemPath = SecurityHelpers.sanitizeForAppleScript(item.path)
                    let itemName = SecurityHelpers.sanitizeForAppleScript(item.name)
                    let script = """
                    tell application "System Events"
                        try
                            make login item at end with properties {path:"\(itemPath)", hidden:false, name:"\(itemName)"}
                            return "ok"
                        on error
                            return "fail"
                        end try
                    end tell
                    """
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = FileHandle.nullDevice
                    do {
                        try process.run()
                        process.waitUntilExit()
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        continuation.resume(returning: output == "ok" || process.terminationStatus == 0)
                    } catch {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    /// Escalates plist modification and launchctl commands via osascript admin prompt.
    private func escalatedToggle(item: StartupItem, newDisabledValue: Bool) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                // Build a shell command that modifies the plist and runs launchctl
                let safePathShell = SecurityHelpers.sanitizeForShell(item.path)
                let disabledStr = newDisabledValue ? "true" : "false"
                let launchctlCmd = newDisabledValue ? "unload -w" : "load -w"
                let shellCmd = "/usr/bin/defaults write \(safePathShell) Disabled -bool \(disabledStr) && /bin/launchctl \(launchctlCmd) \(safePathShell)"
                let escapedShellCmd = SecurityHelpers.sanitizeForAppleScript(shellCmd)
                let script = "do shell script \"\(escapedShellCmd)\" with administrator privileges"

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
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
    }
}
