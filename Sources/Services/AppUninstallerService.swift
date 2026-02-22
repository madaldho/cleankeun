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
        let appDirs = ["/Applications", "\(NSHomeDirectory())/Applications"]

        for dir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = (dir as NSString).appendingPathComponent(item)
                if let app = getAppInfo(path: appPath) {
                    apps.append(app)
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

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleId,
            path: path,
            size: size,
            icon: icon,
            vendor: vendor,
            source: source,
            relatedFiles: relatedFiles
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

        let searchMap: [(String, RelatedFileType)] = [
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

        for (path, type) in searchMap {
            if fileManager.fileExists(atPath: path) {
                let size = sizeOfItem(at: path)
                related.append(RelatedFile(path: path, size: size, type: type))
            }
        }

        return related
    }

    func uninstallApp(_ app: InstalledApp) -> (success: Bool, errors: [String]) {
        var errors: [String] = []
        // Try to remove the main app bundle first
        var appRemoved = false
        do {
            try fileManager.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
            appRemoved = true
        } catch {
            errors.append("Failed to remove app: \(error.localizedDescription)")
            return (false, errors)
        }
        // Clean up related files — failures here shouldn't make the whole operation "failed"
        for rf in app.relatedFiles {
            do {
                try fileManager.trashItem(at: URL(fileURLWithPath: rf.path), resultingItemURL: nil)
            } catch {
                errors.append("Failed to remove \(rf.fileName): \(error.localizedDescription)")
            }
        }
        // BUG-33: Report success if the app itself was removed, even if some related files failed
        return (appRemoved, errors)
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
        if let enumerator = fileManager.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                    let size = attrs[.size] as? Int64
                {
                    total += size
                }
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
