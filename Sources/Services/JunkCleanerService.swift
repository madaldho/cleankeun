//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class JunkCleanerService {

    static let shared = JunkCleanerService()
    private let fileManager = FileManager.default

    /// Special path sentinel for the purgeable space virtual item
    static let purgeableSpacePath = "__cleankeun_purgeable_space__"

    /// Result of a Flash Clean scan
    struct ScanResult {
        let items: [JunkItem]
        let trashAccessDenied: Bool
    }

    // MARK: - Scan for Junk (BuhoCleaner-style categories)
    func scanForJunk(
        onProgress: ((String, Int) -> Void)? = nil
    ) async -> ScanResult {
        var items: [JunkItem] = []
        let home = NSHomeDirectory()
        var trashAccessDenied = false
        
        let purgeableSize = getPurgeableSpaceSize()
        if purgeableSize > 0 {
            items.append(JunkItem(path: "Purgeable Space", size: purgeableSize, category: .purgeableSpace, isSelected: true))
        }

        // Browser cache directory prefixes to exclude from generic userCache scan
        let browserCachePrefixes = [
            "\(home)/Library/Caches/com.apple.Safari",
            "\(home)/Library/Caches/Google",
            "\(home)/Library/Caches/com.google.Chrome",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Caches/org.mozilla.firefox",
            "\(home)/Library/Caches/company.thebrowser.Browser",
            "\(home)/Library/Caches/com.brave.Browser",
            "\(home)/Library/Caches/com.microsoft.edgemac",
            "\(home)/Library/Caches/com.operasoftware.Opera",
        ]

        // 1. System Cache Files — system-level temp/cache dirs
        let systemCacheTargets: [String] = [
            NSTemporaryDirectory(),
            "/private/var/folders",
            "/Library/Caches",
        ]
        for path in systemCacheTargets {
            let found = scanDirectory(
                path: path, category: .systemCache,
                onProgress: onProgress, currentCount: items.count
            )
            items.append(contentsOf: found)
        }

        // 3. User Cache Files — ~/Library/Caches (excluding browser caches)
        let userCacheFound = scanDirectory(
            path: "\(home)/Library/Caches", category: .userCache,
            excludePrefixes: browserCachePrefixes,
            onProgress: onProgress, currentCount: items.count
        )
        items.append(contentsOf: userCacheFound)

        // 4. Xcode Junk
        let xcodeTargets = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
            "\(home)/Library/Developer/CoreSimulator/Caches",
        ]
        for path in xcodeTargets {
            let found = scanDirectory(
                path: path, category: .xcode,
                onProgress: onProgress, currentCount: items.count
            )
            items.append(contentsOf: found)
        }

        // 5. Browser Caches — per-browser tagging
        let browserTargets: [(path: String, browser: BrowserApp)] = [
            ("\(home)/Library/Caches/com.apple.Safari", .safari),
            ("\(home)/Library/Safari", .safari),
            ("\(home)/Library/Caches/Google/Chrome", .chrome),
            ("\(home)/Library/Caches/com.google.Chrome", .chrome),
            ("\(home)/Library/Caches/Firefox", .firefox),
            ("\(home)/Library/Caches/org.mozilla.firefox", .firefox),
            ("\(home)/Library/Caches/company.thebrowser.Browser", .arc),
            ("\(home)/Library/Caches/com.brave.Browser", .brave),
            ("\(home)/Library/Caches/com.microsoft.edgemac", .edge),
            ("\(home)/Library/Caches/com.operasoftware.Opera", .opera),
        ]
        for target in browserTargets {
            let found = scanDirectory(
                path: target.path, category: .browserCache,
                browserApp: target.browser,
                onProgress: onProgress, currentCount: items.count
            )
            items.append(contentsOf: found)
        }

        // 6. System Log Files — /private/var/log, /Library/Logs (excluding DiagnosticReports)
        let systemLogTargets: [(path: String, excludePrefixes: [String])] = [
            ("/private/var/log", []),
            ("/Library/Logs", ["/Library/Logs/DiagnosticReports"]),
        ]
        for target in systemLogTargets {
            let found = scanDirectory(
                path: target.path, category: .systemLogs,
                excludePrefixes: target.excludePrefixes,
                onProgress: onProgress, currentCount: items.count
            )
            items.append(contentsOf: found)
        }

        // 7. Crash Reports
        let crashTargets = [
            "\(home)/Library/Logs/DiagnosticReports",
            "/Library/Logs/DiagnosticReports",
        ]
        for path in crashTargets {
            let found = scanDirectory(
                path: path, category: .crashReports,
                onProgress: onProgress, currentCount: items.count
            )
            items.append(contentsOf: found)
        }

        // 8. Unused DMG Files — top-level .dmg in ~/Downloads
        let dmgItems = scanDMGs(in: "\(home)/Downloads", onProgress: onProgress, currentCount: items.count)
        items.append(contentsOf: dmgItems)

        // 9. User Log Files — ~/Library/Logs (excluding DiagnosticReports)
        let userLogFound = scanDirectory(
            path: "\(home)/Library/Logs", category: .userLogs,
            excludePrefixes: ["\(home)/Library/Logs/DiagnosticReports"],
            onProgress: onProgress, currentCount: items.count
        )
        items.append(contentsOf: userLogFound)

        // 10. Trash Can — ~/.Trash (may fail without FDA)
        let trashPath = "\(home)/.Trash"
        do {
            let trashContents = try fileManager.contentsOfDirectory(atPath: trashPath)
            let realItems = trashContents.filter { $0 != ".DS_Store" && $0 != ".localized" }
            for file in realItems {
                let fullPath = (trashPath as NSString).appendingPathComponent(file)
                let size = sizeOfItem(atPath: fullPath)
                if size > 0 {
                    items.append(JunkItem(
                        path: fullPath, size: size, category: .trashCan,
                        isSelected: false // NOT auto-selected
                    ))
                    if items.count % 10 == 0 {
                        onProgress?(fullPath, items.count)
                    }
                }
            }
        } catch {
            // Permission denied = no Full Disk Access
            let nsError = error as NSError
            if nsError.code == NSFileReadNoPermissionError
                || nsError.code == 257
                || error.localizedDescription.contains("Operation not permitted") {
                trashAccessDenied = true
            }
        }

        // 11. Downloads — all files in ~/Downloads (top-level only, excluding .dmg)
        let downloadItems = scanDownloads(
            in: "\(home)/Downloads",
            onProgress: onProgress, currentCount: items.count
        )
        items.append(contentsOf: downloadItems)

        // 12. Screen Capture Files — screenshots on Desktop
        let screenshotItems = scanScreenCaptures(onProgress: onProgress, currentCount: items.count)
        items.append(contentsOf: screenshotItems)

        // 13. Mail Attachments
        let mailTargets = [
            "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
        ]
        for path in mailTargets {
            let found = scanDirectory(
                path: path, category: .mailAttachments,
                onProgress: onProgress, currentCount: items.count
            )
            items.append(contentsOf: found)
        }

        // 14. iOS Backups
        let iosBackupFound = scanDirectory(
            path: "\(home)/Library/Application Support/MobileSync/Backup",
            category: .iOSBackups,
            onProgress: onProgress, currentCount: items.count
        )
        items.append(contentsOf: iosBackupFound)

        return ScanResult(items: items, trashAccessDenied: trashAccessDenied)
    }

    // MARK: - Purgeable Space Size
    /// Returns macOS purgeable space in bytes.
    /// Purgeable = volumeAvailableCapacityForImportantUsage - volumeAvailableCapacity
    private func getPurgeableSpaceSize() -> Int64 {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]) else { return 0 }

        let important = values.volumeAvailableCapacityForImportantUsage ?? 0
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        let purgeable = important - available
        return max(0, purgeable)
    }

    // MARK: - Scan Downloads (top-level, non-recursive, excluding .dmg)
    private func scanDownloads(
        in path: String,
        onProgress: ((String, Int) -> Void)? = nil,
        currentCount: Int = 0
    ) -> [JunkItem] {
        var items: [JunkItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return items }
        for file in contents {
            // Skip hidden files, .dmg (counted separately in unusedDMGs), .DS_Store
            if file.hasPrefix(".") { continue }
            if file.lowercased().hasSuffix(".dmg") { continue }

            let fullPath = (path as NSString).appendingPathComponent(file)
            let size = sizeOfItem(atPath: fullPath)
            if size > 0 {
                items.append(JunkItem(
                    path: fullPath, size: size, category: .downloads,
                    isSelected: false // NOT auto-selected — user's files
                ))
                if items.count % 10 == 0 {
                    onProgress?(fullPath, currentCount + items.count)
                }
            }
        }
        return items
    }

    // MARK: - Scan Screen Captures
    private func scanScreenCaptures(
        onProgress: ((String, Int) -> Void)? = nil,
        currentCount: Int = 0
    ) -> [JunkItem] {
        var items: [JunkItem] = []
        let home = NSHomeDirectory()

        // macOS default screenshot location is ~/Desktop
        // Could also be customized via `defaults read com.apple.screencapture location`
        let screenshotDir = "\(home)/Desktop"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: screenshotDir) else { return items }

        // macOS screenshot naming patterns (varies by locale/version):
        // "Screenshot *.png", "Screen Shot *.png", "Bildschirmfoto *.png",
        // "Capture d'écran *.png", "Captura de pantalla *.png"
        let screenshotPrefixes = [
            "Screenshot", "Screen Shot", "Bildschirmfoto",
            "Capture d'écran", "Captura de pantalla", "Captura de Tela",
            "スクリーンショット", "截屏", "截圖",
        ]
        let screenshotExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "heic"]

        for file in contents {
            let ext = (file as NSString).pathExtension.lowercased()
            guard screenshotExtensions.contains(ext) else { continue }

            let isScreenshot = screenshotPrefixes.contains { file.hasPrefix($0) }
            guard isScreenshot else { continue }

            let fullPath = (screenshotDir as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let fileSize = attrs[.size] as? Int64,
               fileSize > 0 {
                let fileType = attrs[.type] as? FileAttributeType
                if fileType != FileAttributeType.typeDirectory {
                    items.append(JunkItem(
                        path: fullPath, size: fileSize, category: .screenCaptures,
                        isSelected: false // NOT auto-selected — user's files
                    ))
                    if items.count % 5 == 0 {
                        onProgress?(fullPath, currentCount + items.count)
                    }
                }
            }
        }
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
                    items.append(JunkItem(path: fullPath, size: fileSize, category: .unusedDMGs,
                                         isSelected: false))
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
        excludePrefixes: [String] = [],
        browserApp: BrowserApp? = nil,
        onProgress: ((String, Int) -> Void)? = nil,
        currentCount: Int = 0
    ) -> [JunkItem] {
        var items: [JunkItem] = []
        guard fileManager.fileExists(atPath: path) else { return items }

        // Use smart-selection default: safe categories start selected, others don't
        let defaultSelected = category.isSafeToAutoSelect

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return items }

        for file in contents {
            // Skip hidden files/folders to avoid breaking system internals like .DS_Store
            if file.hasPrefix(".") { continue }

            let fullPath = (path as NSString).appendingPathComponent(file)

            // Skip excluded prefix paths
            if !excludePrefixes.isEmpty {
                let shouldExclude = excludePrefixes.contains { fullPath.hasPrefix($0) }
                if shouldExclude {
                    continue
                }
            }

            let size = sizeOfItem(atPath: fullPath)
            if size > 0 {
                items.append(JunkItem(
                    path: fullPath, size: size, category: category,
                    browserApp: browserApp, isSelected: defaultSelected
                ))
                if items.count % 5 == 0 {
                    onProgress?(fullPath, currentCount + items.count)
                }
            }
        }
        return items
    }

    // MARK: - Size of Item (file or directory, recursive)
    private func sizeOfItem(atPath path: String) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        
        if isDir.boolValue {
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
        } else {
            let attrs = try? fileManager.attributesOfItem(atPath: path)
            return (attrs?[.size] as? Int64) ?? 0
        }
    }

    // MARK: - Clean Items with Progress
    func cleanItemsWithProgress(
        _ items: [JunkItem],
        onProgress: @escaping (Int, Int, Int64, String) -> Void
    ) -> (deleted: Int, freedSpace: Int64, errors: [String]) {
        var deleted = 0
        var freedSpace: Int64 = 0
        var errors: [String] = []
        // Filter out virtual items (purgeable space) — handled separately in ViewModel
        let selected = items.filter { $0.isSelected && !$0.category.isVirtual }
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
