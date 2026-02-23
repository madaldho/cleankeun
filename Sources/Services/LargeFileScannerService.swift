//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class LargeFileScannerService {
    static let shared = LargeFileScannerService()
    private let fileManager = FileManager.default

    func scanLargeFiles(minimumSize: Int64 = 50 * 1024 * 1024, fileType: LargeFileType? = nil) async -> [LargeFile] {
        var files: [LargeFile] = []
        let home = NSHomeDirectory()
        let searchPaths = [
            "\(home)/Downloads", "\(home)/Desktop", "\(home)/Documents",
            "\(home)/Movies", "\(home)/Music", "\(home)/Pictures",
        ]

        for searchPath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                if SecurityHelpers.isSymlink(url.path) { continue }
                do {
                    let rv = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                    if rv.isDirectory == true { continue }
                    if let fs = rv.fileSize, Int64(fs) >= minimumSize {
                        let detectedType = LargeFileType.detect(from: url.path)
                        if let filterType = fileType, detectedType != filterType { continue }
                        files.append(LargeFile(
                            path: url.path, size: Int64(fs),
                            modificationDate: rv.contentModificationDate ?? Date(),
                            fileType: detectedType
                        ))
                    }
                } catch { continue }
            }
        }
        return files.sorted { $0.size > $1.size }
    }

    func deleteFiles(_ files: [LargeFile]) -> (deleted: Int, freedSpace: Int64, errors: [String]) {
        var deleted = 0; var freedSpace: Int64 = 0; var errors: [String] = []
        for file in files where file.isSelected {
            guard SecurityHelpers.isPathSafeForDeletion(file.path) else {
                errors.append("Blocked unsafe deletion path: \(file.fileName)")
                continue
            }
            do {
                try fileManager.removeItem(atPath: file.path)
                deleted += 1; freedSpace += file.size
            } catch { errors.append("\(file.fileName): \(error.localizedDescription)") }
        }
        return (deleted, freedSpace, errors)
    }
}
