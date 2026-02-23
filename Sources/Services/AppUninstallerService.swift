//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import AppKit
import Foundation

class AppUninstallerService {
    static let shared = AppUninstallerService()
    private let fileManager = FileManager.default

    func scanInstalledApps() async -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let appDirs = ["/Applications", "\(NSHomeDirectory())/Applications", "/Applications/Utilities", "/opt/homebrew/Caskroom"]

        for dir in appDirs {
            guard fileManager.fileExists(atPath: dir) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            
            while let url = enumerator.nextObject() as? URL {
                if url.pathExtension.lowercased() == "app" {
                    if let app = getAppInfo(path: url.path) {
                        apps.append(app)
                    }
                    // Don't recurse inside the .app bundle
                    enumerator.skipDescendants()
                }
            }
        }

        return apps.sorted { $0.totalSize > $1.totalSize }
    }

    private func getAppInfo(path: String) -> InstalledApp? {
        let plistPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plistData = fileManager.contents(atPath: plistPath),
            let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil)
                as? [String: Any]
        else {
            return nil
        }

        let bundleId = plist["CFBundleIdentifier"] as? String ?? ""
        let name =
            plist["CFBundleName"] as? String
            ?? plist["CFBundleDisplayName"] as? String
            ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension

        let size = directorySize(path: path)
        let icon = NSWorkspace.shared.icon(forFile: path)
        let relatedFiles = findRelatedFiles(bundleId: bundleId, appName: name)

        // Detect Source
        let hasReceipt = fileManager.fileExists(
            atPath: (path as NSString).appendingPathComponent("Contents/_MASReceipt/receipt"))
        let source: AppSource = hasReceipt ? .appStore : .other

        // Detect Vendor
        let vendor = determineVendor(bundleId: bundleId)

        // Get last used date
        var lastUsedDate: Date? = nil
        let mdItem = MDItemCreate(kCFAllocatorDefault, path as CFString)
        if let item = mdItem,
           let date = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date {
            lastUsedDate = date
        } else if let attrs = try? fileManager.attributesOfItem(atPath: path),
                  let date = attrs[.modificationDate] as? Date {
            // Fallback to modification date if spotlight doesn't have it
            lastUsedDate = date
        }

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            size: size,
            icon: icon,
            vendor: vendor,
            source: source,
            relatedFiles: relatedFiles,
            lastUsedDate: lastUsedDate
        )
    }

    private func determineVendor(bundleId: String) -> AppVendor {
        let lower = bundleId.lowercased()
        if lower.starts(with: "com.apple.") { return .apple }
        if lower.starts(with: "com.google.") { return .google }
        if lower.starts(with: "com.microsoft.") { return .microsoft }
        if lower.starts(with: "com.adobe.") { return .adobe }
        return .other
    }

    func findRelatedFiles(bundleId: String, appName: String) -> [RelatedFile] {
        var related: [RelatedFile] = []
        let home = NSHomeDirectory()

        var searchMap: [(String, RelatedFileType)] = [
            ("\(home)/Library/Application Support/\(appName)", .applicationSupport),
            ("\(home)/Library/Application Support/\(bundleId)", .applicationSupport),
            ("\(home)/Library/Caches/\(bundleId)", .cache),
            ("\(home)/Library/Caches/\(appName)", .cache),
            ("\(home)/Library/Preferences/\(bundleId).plist", .preferences),
            ("\(home)/Library/Logs/\(appName)", .logs),
            ("\(home)/Library/Logs/\(bundleId)", .logs),
            ("\(home)/Library/Containers/\(bundleId)", .container),
            ("\(home)/Library/Group Containers/\(bundleId)", .container),
            ("\(home)/Library/Saved Application State/\(bundleId).savedState", .savedState),
            ("\(home)/Library/WebKit/\(bundleId)", .webKit),
            ("\(home)/Library/HTTPStorages/\(bundleId)", .other),
            ("\(home)/Library/Cookies/\(bundleId).binarycookies", .other),
        ]
        
        // Special heavy app paths
        if appName.contains("Android Studio") || bundleId.contains("android.studio") {
            searchMap.append(("\(home)/Library/Android", .applicationSupport))
            searchMap.append(("\(home)/.android", .applicationSupport))
            searchMap.append(("\(home)/.gradle", .applicationSupport))
            searchMap.append(("\(home)/Library/Application Support/Google/AndroidStudio", .applicationSupport))
        }
        
        if appName.contains("Xcode") || bundleId == "com.apple.dt.Xcode" {
            searchMap.append(("\(home)/Library/Developer/Xcode", .applicationSupport))
            searchMap.append(("\(home)/Library/Developer/CoreSimulator", .applicationSupport))
        }
        
        if appName.contains("Docker") || bundleId.contains("docker") {
            searchMap.append(("\(home)/Library/Containers/com.docker.docker", .container))
            searchMap.append(("\(home)/.docker", .applicationSupport))
        }

        // Generic Vendor fallback (e.g., com.google.Chrome -> Google/Chrome)
        let parts = bundleId.split(separator: ".")
        if parts.count >= 2 {
            let possibleVendor = String(parts[1])
            let vendorName = possibleVendor.prefix(1).capitalized + possibleVendor.dropFirst()
            searchMap.append(("\(home)/Library/Application Support/\(vendorName)/\(appName)", .applicationSupport))
            searchMap.append(("\(home)/Library/Caches/\(vendorName)/\(appName)", .cache))
        }

        // Special: Google Chrome
        if appName == "Google Chrome" || bundleId == "com.google.Chrome" {
            searchMap.append(("\(home)/Library/Application Support/Google/Chrome", .applicationSupport))
            searchMap.append(("\(home)/Library/Caches/Google/Chrome", .cache))
            searchMap.append(("\(home)/Library/Preferences/com.google.Keystone.Agent.plist", .preferences))
            searchMap.append(("\(home)/Library/Preferences/Google Chrome Brand.plist", .preferences))
            searchMap.append(("\(home)/Applications/Chrome Apps.localized", .applicationSupport))
            // Sometimes it's localized in Indonesian as "Aplikasi Chrome"
            searchMap.append(("\(home)/Applications/Aplikasi Chrome", .applicationSupport))
            searchMap.append(("\(home)/Applications/Chrome Apps", .applicationSupport))
        }

        // Special: Firefox
        if appName == "Firefox" || bundleId == "org.mozilla.firefox" {
            searchMap.append(("\(home)/Library/Application Support/Firefox", .applicationSupport))
            searchMap.append(("\(home)/Library/Caches/Firefox", .cache))
            searchMap.append(("\(home)/Library/Caches/Mozilla/updates/Applications/Firefox", .cache))
        }

        // Special: Visual Studio Code
        if appName == "Visual Studio Code" || bundleId == "com.microsoft.VSCode" {
            searchMap.append(("\(home)/.vscode", .library))
            searchMap.append(("\(home)/.vscode-react-native", .library))
            searchMap.append(("\(home)/Library/Application Support/Code", .applicationSupport))
            searchMap.append(("\(home)/Library/Caches/com.microsoft.VSCode.ShipIt", .cache))
            searchMap.append(("\(home)/Library/Caches/com.microsoft.VSCode", .cache))
            searchMap.append(("\(home)/Library/Saved Application State/com.microsoft.VSCode.savedState", .savedState))
            searchMap.append(("\(home)/Library/Preferences/com.microsoft.VSCode.plist", .preferences))
            searchMap.append(("\(home)/Library/Microsoft", .library))
        }

        // Generic fallback for hidden dotfiles/folders based on app name
        // E.g. "bun" -> "~/.bun", "npm" -> "~/.npm", "Cursor" -> "~/.cursor"
        let lowerAppName = appName.lowercased().replacingOccurrences(of: " ", with: "")
        if !lowerAppName.isEmpty {
            searchMap.append(("\(home)/.\(lowerAppName)", .library))
            searchMap.append(("\(home)/.\(lowerAppName)-cli", .library))
        }

        // Remove duplicates and check existence
        var uniquePaths = Set<String>()
        var finalSearchMap = [(String, RelatedFileType)]()
        for (path, type) in searchMap {
            if !uniquePaths.contains(path) {
                uniquePaths.insert(path)
                finalSearchMap.append((path, type))
            }
        }

        for (path, type) in finalSearchMap {
            if fileManager.fileExists(atPath: path) {
                let size = sizeOfItem(at: path)
                related.append(RelatedFile(path: path, size: size, type: type))
            }
        }

        return related
    }

    func uninstallApp(_ app: InstalledApp) -> (success: Bool, errors: [String]) {
        var errors: [String] = []
        var success = true
        
        if app.isBundleSelected {
            do {
                try fileManager.removeItem(atPath: app.path)
            } catch {
                errors.append("Failed to remove app: \(error.localizedDescription)")
                success = false
            }
        }
        
        for rf in app.relatedFiles where rf.isSelected {
            do {
                try fileManager.removeItem(atPath: rf.path)
            } catch {
                errors.append("Failed to remove \(rf.fileName): \(error.localizedDescription)")
                success = false
            }
        }
        
        return (success, errors)
    }

    // Scan for leftover files from already-uninstalled apps
    func scanLeftovers() async -> [RelatedFile] {
        let home = NSHomeDirectory()
        var leftovers: [RelatedFile] = []

        // Get list of installed bundle IDs
        let installedBundleIds = Set(
            (try? FileManager.default.contentsOfDirectory(atPath: "/Applications"))?
                .filter { $0.hasSuffix(".app") }
                .compactMap { app -> String? in
                    let plistPath = "/Applications/\(app)/Contents/Info.plist"
                    guard let data = FileManager.default.contents(atPath: plistPath),
                        let plist = try? PropertyListSerialization.propertyList(
                            from: data, format: nil) as? [String: Any]
                    else { return nil }
                    return plist["CFBundleIdentifier"] as? String
                } ?? []
        )

        // Check Application Support for orphaned folders
        let supportPath = "\(home)/Library/Application Support"
        if let items = try? fileManager.contentsOfDirectory(atPath: supportPath) {
            for item in items {
                let fullPath = (supportPath as NSString).appendingPathComponent(item)
                // BUG-15: Require reverse-domain pattern (at least 2 dots) to reduce false positives
                if item.components(separatedBy: ".").count >= 3
                    && !installedBundleIds.contains(item)
                {
                    let size = sizeOfItem(at: fullPath)
                    if size > 1024 {  // > 1KB
                        leftovers.append(
                            RelatedFile(path: fullPath, size: size, type: .applicationSupport))
                    }
                }
            }
        }

        // Check Caches
        let cachesPath = "\(home)/Library/Caches"
        if let items = try? fileManager.contentsOfDirectory(atPath: cachesPath) {
            for item in items {
                if item.contains(".") && !installedBundleIds.contains(item)
                    && !item.hasPrefix("com.apple")
                {
                    let fullPath = (cachesPath as NSString).appendingPathComponent(item)
                    let size = sizeOfItem(at: fullPath)
                    if size > 1024 {
                        leftovers.append(RelatedFile(path: fullPath, size: size, type: .cache))
                    }
                }
            }
        }

        return leftovers.sorted { $0.size > $1.size }
    }

    private func directorySize(path: String) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        while let url = enumerator.nextObject() as? URL {
            if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
               let size = values.totalFileAllocatedSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func sizeOfItem(at path: String) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if isDir.boolValue {
            return directorySize(path: path)
        } else {
            return (try? fileManager.attributesOfItem(atPath: path))?[.size] as? Int64 ?? 0
        }
    }
}
