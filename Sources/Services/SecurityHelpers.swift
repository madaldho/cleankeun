//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation

enum SecurityHelpers {
    
    /// Escapes a string for safe interpolation within an AppleScript double-quoted string.
    static func sanitizeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    
    /// Escapes a string for safe use as a shell argument by wrapping it in single quotes
    /// and safely escaping any internal single quotes.
    static func sanitizeForShell(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
    
    /// Checks if a given path is a symbolic link.
    static func isSymlink(_ path: String) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return false }
        return attrs[.type] as? FileAttributeType == .typeSymbolicLink
    }
    
    /// Validates a path to ensure it does not point to critical system directories
    /// or the application's own bundle. Resolves symlinks before checking.
    static func isPathSafeForDeletion(_ path: String) -> Bool {
        // Resolve symlinks to get the real target path
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let realPath = resolvedURL.path
        
        let blocklist = [
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/var",
            "/private",
            "/Library/Apple",
            "/Library/CoreMediaIO",
            "/Library/Preferences/SystemConfiguration",
            "/Applications/Safari.app",
            "/Applications/Utilities/Terminal.app",
            "/Applications/Utilities/Activity Monitor.app",
            "/Applications/Utilities/Disk Utility.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Applications/Utilities/Activity Monitor.app",
            "/System/Applications/Utilities/Disk Utility.app"
        ]
        
        // Block exact matches or sub-paths of critical directories
        for blocked in blocklist {
            if realPath == blocked || realPath.hasPrefix(blocked + "/") {
                return false
            }
        }
        
        // Protect the app itself
        let appBundlePath = Bundle.main.bundlePath
        if realPath == appBundlePath || realPath.hasPrefix(appBundlePath + "/") {
            return false
        }
        
        // Protect the user's home directory root (cannot delete ~ directly)
        let homeDir = NSHomeDirectory()
        if realPath == homeDir || realPath == homeDir + "/" {
            return false
        }
        
        // Protect / itself
        if realPath == "/" {
            return false
        }
        
        return true
    }
}
