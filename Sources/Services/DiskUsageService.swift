//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import AppKit
import Foundation

/// Represents a mountable volume for the disk picker
struct VolumeInfo: Identifiable {
    let id = UUID()
    let name: String
    let mountPoint: String
    let totalSize: Int64
    let freeSize: Int64
    let icon: NSImage

    var usedSize: Int64 { totalSize - freeSize }
    var usagePercent: Double {
        guard totalSize > 0 else { return 0 }
        return Double(usedSize) / Double(totalSize)
    }
}

class DiskUsageService {
    static let shared = DiskUsageService()
    private let fileManager = FileManager.default

    // MARK: - Volume Discovery

    /// Returns user-relevant mounted volumes (skips system/internal volumes)
    func getAvailableVolumes() -> [VolumeInfo] {
        var volumes: [VolumeInfo] = []

        // Always include the boot volume (Macintosh HD / Data)
        let home = NSHomeDirectory()
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: home) {
            let total = attrs[.systemSize] as? Int64 ?? 0
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            let icon = NSWorkspace.shared.icon(forFile: "/")
            volumes.append(VolumeInfo(
                name: "Macintosh HD",
                mountPoint: home,
                totalSize: total,
                freeSize: free,
                icon: icon
            ))
        }

        // Scan /Volumes for external/additional volumes
        let volumesPath = "/Volumes"
        if let entries = try? fileManager.contentsOfDirectory(atPath: volumesPath) {
            for entry in entries {
                // Skip "Macintosh HD" symlink and hidden volumes
                if entry == "Macintosh HD" || entry.hasPrefix(".") { continue }

                let mountPoint = (volumesPath as NSString).appendingPathComponent(entry)

                // Skip if it's a symlink (macOS creates symlinks in /Volumes for system volumes)
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: mountPoint, isDirectory: &isDir),
                      isDir.boolValue else { continue }

                // Check if it's a symlink
                if let _ = try? fileManager.destinationOfSymbolicLink(atPath: mountPoint) {
                    continue  // Skip symlinks
                }

                if let attrs = try? fileManager.attributesOfFileSystem(forPath: mountPoint) {
                    let total = attrs[.systemSize] as? Int64 ?? 0
                    let free = attrs[.systemFreeSize] as? Int64 ?? 0

                    // Skip tiny volumes (< 100MB — likely system partitions)
                    guard total > 100 * 1024 * 1024 else { continue }

                    let icon = NSWorkspace.shared.icon(forFile: mountPoint)
                    volumes.append(VolumeInfo(
                        name: entry,
                        mountPoint: mountPoint,
                        totalSize: total,
                        freeSize: free,
                        icon: icon
                    ))
                }
            }
        }

        return volumes
    }

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
