//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation
import CommonCrypto

class DuplicateFinderService {
    static let shared = DuplicateFinderService()
    private let fileManager = FileManager.default

    func scanForDuplicates() async -> [DuplicateGroup] {
        let home = NSHomeDirectory()
        let searchPaths = [
            "\(home)/Downloads", "\(home)/Desktop",
            "\(home)/Documents", "\(home)/Pictures",
        ]

        var sizeMap: [Int64: [String]] = [:]
        for searchPath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                do {
                    let rv = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    if rv.isDirectory == true { continue }
                    if let fs = rv.fileSize, fs > 1024 {
                        sizeMap[Int64(fs), default: []].append(url.path)
                    }
                } catch { continue }
            }
        }

        var groups: [DuplicateGroup] = []
        for (fileSize, paths) in sizeMap where paths.count > 1 {
            var hashMap: [String: [String]] = [:]
            for path in paths {
                if let hash = computePartialHash(path: path) {
                    hashMap[hash, default: []].append(path)
                }
            }
            // BUG-13: Verify partial-hash matches with full-file hash to avoid false positives
            for (_, dups) in hashMap where dups.count > 1 {
                var fullHashMap: [String: [String]] = [:]
                for dup in dups {
                    if let fullHash = computeFullHash(path: dup) {
                        fullHashMap[fullHash, default: []].append(dup)
                    }
                }
                for (fullHash, verifiedDups) in fullHashMap where verifiedDups.count > 1 {
                    let ft = LargeFileType.detect(from: verifiedDups[0])
                    let files = verifiedDups.map { DuplicateFile(path: $0, size: fileSize) }
                    groups.append(DuplicateGroup(hash: fullHash, fileSize: fileSize, fileType: ft, files: files))
                }
            }
        }
        return groups.sorted { $0.wastedSpace > $1.wastedSpace }
    }

    private func computePartialHash(path: String, sampleSize: Int = 8192) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: sampleSize)
        guard !data.isEmpty else { return nil }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute full SHA-256 hash of the entire file for verification (BUG-13)
    private func computeFullHash(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        let chunkSize = 1024 * 1024 // 1MB chunks
        while true {
            let data = handle.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            data.withUnsafeBytes { _ = CC_SHA256_Update(&context, $0.baseAddress, CC_LONG(data.count)) }
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func deleteFiles(_ files: [DuplicateFile]) -> (deleted: Int, freedSpace: Int64, errors: [String]) {
        var deleted = 0; var freedSpace: Int64 = 0; var errors: [String] = []
        for file in files where file.isSelected {
            do {
                try fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                deleted += 1; freedSpace += file.size
            } catch { errors.append("\(file.fileName): \(error.localizedDescription)") }
        }
        return (deleted, freedSpace, errors)
    }
}
