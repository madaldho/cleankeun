//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class JunkCleanerService {

    static let shared = JunkCleanerService()
    private let fileManager = FileManager.default

    // MARK: - Scan for Junk (with progress reporting)
    func scanForJunk(
        onProgress: ((String, Int) -> Void)? = nil
    ) async -> [JunkItem] {
        var items: [JunkItem] = []
        let home = NSHomeDirectory()

        // Define all scan targets with their categories
        let scanTargets: [(path: String, category: JunkCategory)] = [
            // Application Cache
            ("\(home)/Library/Caches", .appCache),
            // System Logs
            ("\(home)/Library/Logs", .logs),
            ("/private/var/log", .logs),
            // Temporary Files
            (NSTemporaryDirectory(), .tempFiles),
            ("/private/var/folders", .tempFiles),
            // Browser Cache
            ("\(home)/Library/Caches/Google/Chrome", .browserCache),
            ("\(home)/Library/Caches/com.apple.Safari", .browserCache),
            ("\(home)/Library/Caches/Firefox", .browserCache),
            ("\(home)/Library/Caches/com.brave.Browser", .browserCache),
            ("\(home)/Library/Caches/com.microsoft.edgemac", .browserCache),
            // Xcode Cache
            ("\(home)/Library/Developer/Xcode/DerivedData", .xcode),
            ("\(home)/Library/Developer/Xcode/Archives", .xcode),
            ("\(home)/Library/Developer/CoreSimulator/Caches", .xcode),
            // Crash Reports
            ("\(home)/Library/Logs/DiagnosticReports", .crashReports),
            ("/Library/Logs/DiagnosticReports", .crashReports),
            // iOS Backups
            ("\(home)/Library/Application Support/MobileSync/Backup", .iOSBackups),
            // Trash
            ("\(home)/.Trash", .trash),
        ]

        for target in scanTargets {
            let found = scanDirectory(path: target.path, category: target.category, onProgress: onProgress, currentCount: items.count)
            items.append(contentsOf: found)
        }

        // Scan for unused DMGs in Downloads (top-level only, not recursive)
        let downloadsPath = "\(home)/Downloads"
        let dmgItems = scanDMGs(in: downloadsPath, onProgress: onProgress, currentCount: items.count)
        items.append(contentsOf: dmgItems)

        return items
    }

    // MARK: - Scan DMGs (top-level only in Downloads)
    private func scanDMGs(
        in path: String,
        onProgress: ((String, Int) -> Void)? = nil,
        currentCount: Int = 0
    ) -> [JunkItem] {
        var items: [JunkItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return items }
        for file in contents where file.lowercased().hasSuffix(".dmg") {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileSize = attrs[.size] as? Int64,
               fileSize > 0 {
                let fileType = attrs[.type] as? FileAttributeType
                if fileType != FileAttributeType.typeDirectory {
                    items.append(JunkItem(path: fullPath, size: fileSize, category: .unusedDMGs))
                    if items.count % 5 == 0 {
                        onProgress?(fullPath, currentCount + items.count)
                    }
                }
            }
        }
        return items
    }

    // MARK: - Scan Directory
    private func scanDirectory(
        path: String,
        category: JunkCategory,
        onProgress: ((String, Int) -> Void)? = nil,
        currentCount: Int = 0
    ) -> [JunkItem] {
        var items: [JunkItem] = []
        guard fileManager.fileExists(atPath: path) else { return items }

        if let enumerator = fileManager.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let fileSize = attrs[.size] as? Int64,
                   fileSize > 0 {
                    let fileType = attrs[.type] as? FileAttributeType
                    if fileType != FileAttributeType.typeDirectory {
                        items.append(JunkItem(path: fullPath, size: fileSize, category: category))
                        // Report progress every 20 files to avoid UI flooding
                        if items.count % 20 == 0 {
                            onProgress?(fullPath, currentCount + items.count)
                        }
                    }
                }
            }
        }
        return items
    }

    // MARK: - Clean Items with Progress
    func cleanItemsWithProgress(
        _ items: [JunkItem],
        onProgress: @escaping (Int, Int, Int64, String) -> Void
    ) -> (deleted: Int, freedSpace: Int64, errors: [String]) {
        var deleted = 0
        var freedSpace: Int64 = 0
        var errors: [String] = []
        let selected = items.filter(\.isSelected)
        let total = selected.count

        for (index, item) in selected.enumerated() {
            onProgress(index, total, freedSpace, item.fileName)
            do {
                try fileManager.removeItem(atPath: item.path)
                deleted += 1
                freedSpace += item.size
            } catch {
                errors.append("Failed to delete \(item.fileName): \(error.localizedDescription)")
            }
        }
        onProgress(total, total, freedSpace, "")
        return (deleted, freedSpace, errors)
    }

    // MARK: - Clean Items (legacy)
    func cleanItems(_ items: [JunkItem]) -> (deleted: Int, freedSpace: Int64, errors: [String]) {
        return cleanItemsWithProgress(items) { _, _, _, _ in }
    }
}
