//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

class FileShredderService {
    static let shared = FileShredderService()
    private let fileManager = FileManager.default

    /// Securely shred a file by overwriting with random data multiple times
    func shredFile(at path: String, passes: Int = 3) throws {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            throw ShredError.fileNotFound
        }

        if isDir.boolValue {
            // Shred all files in directory first
            if let enumerator = fileManager.enumerator(atPath: path) {
                while let file = enumerator.nextObject() as? String {
                    let fullPath = (path as NSString).appendingPathComponent(file)
                    var subDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &subDir), !subDir.boolValue {
                        try shredSingleFile(at: fullPath, passes: passes)
                    }
                }
            }
            try fileManager.removeItem(atPath: path)
        } else {
            try shredSingleFile(at: path, passes: passes)
        }
    }

    private func shredSingleFile(at path: String, passes: Int) throws {
        guard let handle = FileHandle(forUpdatingAtPath: path) else {
            throw ShredError.cannotOpen
        }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else {
            try fileManager.removeItem(atPath: path)
            return
        }

        let bufferSize = min(Int(fileSize), 1024 * 1024) // 1MB chunks

        for _ in 0..<passes {
            handle.seek(toFileOffset: 0)
            var remaining = Int(fileSize)
            while remaining > 0 {
                let chunkSize = min(bufferSize, remaining)
                var randomBytes = [UInt8](repeating: 0, count: chunkSize)
                _ = SecRandomCopyBytes(kSecRandomDefault, chunkSize, &randomBytes)
                handle.write(Data(randomBytes))
                remaining -= chunkSize
            }
            handle.synchronizeFile()
        }

        // Final zero pass — write in chunks to avoid OOM on large files (BUG-04)
        handle.seek(toFileOffset: 0)
        let zeroChunk = Data(count: bufferSize)
        var zeroRemaining = Int(fileSize)
        while zeroRemaining > 0 {
            let chunkSize = min(bufferSize, zeroRemaining)
            if chunkSize == bufferSize {
                handle.write(zeroChunk)
            } else {
                handle.write(Data(count: chunkSize))
            }
            zeroRemaining -= chunkSize
        }
        handle.synchronizeFile()
        // BUG-34: removed explicit closeFile() — defer already handles it

        try fileManager.removeItem(atPath: path)
    }

    enum ShredError: LocalizedError {
        case fileNotFound
        case cannotOpen

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "File not found"
            case .cannotOpen: return "Cannot open file for writing"
            }
        }
    }
}
