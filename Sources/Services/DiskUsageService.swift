//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class DiskUsageService {
    static let shared = DiskUsageService()
    private let fileManager = FileManager.default

    func analyzeDiskUsage(path: String? = nil, maxDepth: Int = 2) async -> [DiskUsageItem] {
        let targetPath = path ?? NSHomeDirectory()
        return scanDirectory(path: targetPath, currentDepth: 0, maxDepth: maxDepth)
    }

    private func scanDirectory(path: String, currentDepth: Int, maxDepth: Int) -> [DiskUsageItem] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
        var items: [DiskUsageItem] = []

        for item in contents {
            if item.hasPrefix(".") { continue } // Skip hidden files

            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let size = directorySize(path: fullPath)
                let children = currentDepth < maxDepth
                    ? scanDirectory(path: fullPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                    : []
                items.append(DiskUsageItem(name: item, path: fullPath, size: size, children: children, isDirectory: true))
            } else {
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int64 {
                    items.append(DiskUsageItem(name: item, path: fullPath, size: size, children: [], isDirectory: false))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    private func directorySize(path: String) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        while let url = enumerator.nextObject() as? URL {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    func getDiskInfo() -> (total: Int64, free: Int64, used: Int64) {
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            return (total, free, total - free)
        } catch {
            return (0, 0, 0)
        }
    }
}
