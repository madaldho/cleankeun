//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class JunkCleanerService {

    static let shared = JunkCleanerService()
    private let fileManager = FileManager.default

    // MARK: - Scan for Junk
    func scanForJunk() async -> [JunkItem] {
        var items: [JunkItem] = []
        let home = NSHomeDirectory()

        // System Cache
        let cachePaths = [
            "\(home)/Library/Caches",
        ]
        for path in cachePaths {
            items.append(contentsOf: scanDirectory(path: path, category: .appCache))
        }

        // System Logs
        let logPaths = [
            "\(home)/Library/Logs",
            "/private/var/log",
        ]
        for path in logPaths {
            items.append(contentsOf: scanDirectory(path: path, category: .logs))
        }

        // Temporary Files
        let tempPaths = [
            NSTemporaryDirectory(),
            "/private/var/folders",
        ]
        for path in tempPaths {
            items.append(contentsOf: scanDirectory(path: path, category: .tempFiles))
        }

        // Browser Cache
        let browserPaths = [
            "\(home)/Library/Caches/Google/Chrome",
            "\(home)/Library/Caches/com.apple.Safari",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Caches/com.brave.Browser",
            "\(home)/Library/Caches/com.microsoft.edgemac",
        ]
        for path in browserPaths {
            items.append(contentsOf: scanDirectory(path: path, category: .browserCache))
        }

        // Xcode Derived Data
        let xcodePaths = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/CoreSimulator/Caches",
        ]
        for path in xcodePaths {
            items.append(contentsOf: scanDirectory(path: path, category: .xcode))
        }

        // Trash
        let trashPath = "\(home)/.Trash"
        items.append(contentsOf: scanDirectory(path: trashPath, category: .trash))

        return items
    }

    // MARK: - Scan Directory
    private func scanDirectory(path: String, category: JunkCategory) -> [JunkItem] {
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
                    }
                }
            }
        }
        return items
    }

    // MARK: - Clean Items
    func cleanItems(_ items: [JunkItem]) -> (deleted: Int, freedSpace: Int64, errors: [String]) {
        var deleted = 0
        var freedSpace: Int64 = 0
        var errors: [String] = []

        for item in items where item.isSelected {
            do {
                // BUG-16: Use trashItem for recoverability instead of permanent removeItem
                try fileManager.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                deleted += 1
                freedSpace += item.size
            } catch {
                errors.append("Failed to delete \(item.fileName): \(error.localizedDescription)")
            }
        }

        return (deleted, freedSpace, errors)
    }
}
