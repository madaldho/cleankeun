//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import AppKit
import Foundation

// MARK: - Junk Item
struct JunkItem: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let category: JunkCategory
    var isSelected: Bool = true

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: JunkItem, rhs: JunkItem) -> Bool { lhs.id == rhs.id }
}

enum JunkCategory: String, CaseIterable, Identifiable {
    case systemCache = "System Cache"
    case appCache = "Application Cache"
    case logs = "System Logs"
    case tempFiles = "Temporary Files"
    case browserCache = "Browser Cache"
    case xcode = "Xcode Cache"
    case mailCache = "Mail Cache"
    case trash = "Trash"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCache: return "internaldrive"
        case .appCache: return "app.badge.checkmark"
        case .logs: return "doc.text"
        case .tempFiles: return "clock.arrow.circlepath"
        case .browserCache: return "globe"
        case .xcode: return "hammer"
        case .mailCache: return "envelope"
        case .trash: return "trash"
        }
    }

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .systemCache: return (0.35, 0.55, 1.0)
        case .appCache: return (0.55, 0.35, 1.0)
        case .logs: return (1.0, 0.6, 0.25)
        case .tempFiles: return (0.4, 0.8, 0.4)
        case .browserCache: return (0.2, 0.78, 0.9)
        case .xcode: return (1.0, 0.4, 0.4)
        case .mailCache: return (1.0, 0.75, 0.3)
        case .trash: return (0.6, 0.6, 0.6)
        }
    }
}

// MARK: - Installed App
struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let path: String
    let size: Int64
    let icon: NSImage?
    let vendor: AppVendor
    let source: AppSource
    var relatedFiles: [RelatedFile]
    var isSelected: Bool = false

    // UI Grouping properties
    var bundleSize: Int64 { size }
    var librarySize: Int64 {
        relatedFiles.filter { $0.group == .library }.reduce(0) { $0 + $1.size }
    }
    var supportSize: Int64 {
        relatedFiles.filter { $0.group == .supportingFiles }.reduce(0) { $0 + $1.size }
    }
    var preferencesSize: Int64 {
        relatedFiles.filter { $0.group == .preferences }.reduce(0) { $0 + $1.size }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var relatedSize: Int64 {
        relatedFiles.reduce(0) { $0 + $1.size }
    }

    var totalSize: Int64 {
        size + relatedSize
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
}

struct RelatedFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let type: RelatedFileType

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileName: String { (path as NSString).lastPathComponent }
    var group: AppComponentGroup { type.group }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RelatedFile, rhs: RelatedFile) -> Bool { lhs.id == rhs.id }
}

enum RelatedFileType: String {
    case preferences = "Preferences"
    case cache = "Cache"
    case applicationSupport = "App Support"
    case container = "Container"
    case savedState = "Saved State"
    case logs = "Logs"
    case webKit = "WebKit Data"
    case other = "Other"

    var group: AppComponentGroup {
        switch self {
        case .preferences: return .preferences
        case .cache, .logs, .webKit: return .library
        case .applicationSupport, .container, .savedState, .other: return .supportingFiles
        }
    }
}

enum AppComponentGroup: String, CaseIterable, Identifiable {
    case bundle = "Bundle"
    case library = "Library"
    case supportingFiles = "Supporting Files"
    case preferences = "Preferences"

    var id: String { rawValue }
}

enum AppVendor: String, CaseIterable, Identifiable {
    case apple = "Apple"
    case google = "Google"
    case microsoft = "Microsoft"
    case adobe = "Adobe"
    case other = "Other"

    var id: String { rawValue }
}

enum AppSource: String, CaseIterable, Identifiable {
    case appStore = "App Store"
    case other = "Other"

    var id: String { rawValue }
}

// MARK: - Large File
struct LargeFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    let modificationDate: Date
    let fileType: LargeFileType
    var isSelected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileName: String { (path as NSString).lastPathComponent }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LargeFile, rhs: LargeFile) -> Bool { lhs.id == rhs.id }
}

enum LargeFileType: String, CaseIterable, Identifiable {
    case video = "Videos"
    case audio = "Audio"
    case image = "Images"
    case archive = "Archives"
    case diskImage = "Disk Images"
    case document = "Documents"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .archive: return "doc.zipper"
        case .diskImage: return "opticaldiscdrive"
        case .document: return "doc.richtext"
        case .other: return "doc"
        }
    }

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .video: return (0.9, 0.3, 0.5)
        case .audio: return (0.3, 0.7, 1.0)
        case .image: return (0.3, 0.85, 0.5)
        case .archive: return (1.0, 0.75, 0.2)
        case .diskImage: return (0.6, 0.4, 1.0)
        case .document: return (0.3, 0.6, 1.0)
        case .other: return (0.6, 0.6, 0.6)
        }
    }

    static func detect(from path: String) -> LargeFileType {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "m4v", "webm": return .video
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff": return .audio
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "raw", "cr2", "nef":
            return .image
        case "zip", "tar", "gz", "rar", "7z", "bz2", "xz": return .archive
        case "dmg", "iso", "pkg", "app": return .diskImage
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key":
            return .document
        default: return .other
        }
    }
}

// MARK: - Duplicate File Group
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let fileSize: Int64
    let fileType: LargeFileType
    var files: [DuplicateFile]

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var wastedSpace: Int64 { fileSize * Int64(max(files.count - 1, 0)) }
    var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: wastedSpace, countStyle: .file)
    }
}

struct DuplicateFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let size: Int64
    var isSelected: Bool = false
    var fileName: String { (path as NSString).lastPathComponent }
    var directory: String { (path as NSString).deletingLastPathComponent }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DuplicateFile, rhs: DuplicateFile) -> Bool { lhs.id == rhs.id }
}

// MARK: - Memory Info
struct MemoryInfo {
    let total: UInt64
    let used: UInt64
    let free: UInt64
    let wired: UInt64
    let active: UInt64
    let inactive: UInt64
    let compressed: UInt64
    let appMemory: UInt64

    // BUG-30: Guard against division by zero when total == 0
    var usagePercentage: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
    // BUG-03: Use Int64(clamping:) to prevent overflow for extreme UInt64 values
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: total), countStyle: .memory)
    }
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: used), countStyle: .memory)
    }
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: free), countStyle: .memory)
    }
}

// MARK: - CPU Info
struct CPUInfo {
    let usagePercentage: Double
    let userPercentage: Double
    let systemPercentage: Double
    let idlePercentage: Double
    let coreCount: Int
    let temperature: Double?  // Celsius
}

// MARK: - Network Info
struct NetworkInfo {
    let uploadSpeed: Int64  // bytes per second
    let downloadSpeed: Int64
    var formattedUpload: String { formatSpeed(uploadSpeed) }
    var formattedDownload: String { formatSpeed(downloadSpeed) }

    private func formatSpeed(_ bytesPerSec: Int64) -> String {
        if bytesPerSec < 1024 { return "\(bytesPerSec) B/s" }
        if bytesPerSec < 1024 * 1024 { return "\(bytesPerSec / 1024) KB/s" }
        return String(format: "%.1f MB/s", Double(bytesPerSec) / 1048576.0)
    }
}

// MARK: - Startup Item
struct StartupItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let type: StartupType
    var isEnabled: Bool
    let bundleIdentifier: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: StartupItem, rhs: StartupItem) -> Bool { lhs.id == rhs.id }
}

enum StartupType: String {
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
    case loginItem = "Login Item"
}

// MARK: - Disk Usage
struct DiskUsageItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    var children: [DiskUsageItem]
    let isDirectory: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Shred Item
struct ShredItem: Identifiable {
    let id = UUID()
    let path: String
    let size: Int64
    let isDirectory: Bool

    var fileName: String { (path as NSString).lastPathComponent }
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Navigation
enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case junkCleaner = "Flash Clean"
    case uninstaller = "App Uninstall"
    case largeFiles = "Large Files"
    case duplicates = "Duplicates"
    case memory = "Performance"
    case startup = "Startup Items"
    case diskUsage = "Disk Analyzer"
    case shredder = "File Shredder"
    case toolkit = "Toolkit"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .junkCleaner: return "bolt.circle.fill"
        case .uninstaller: return "trash.square.fill"
        case .largeFiles: return "arrow.up.doc.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .memory: return "cpu"
        case .startup: return "power.circle.fill"
        case .diskUsage: return "chart.pie.fill"
        case .shredder: return "lock.shield.fill"
        case .toolkit: return "wrench.and.screwdriver.fill"
        }
    }

    var gradient: [GradientStop] {
        switch self {
        case .dashboard:
            return [GradientStop(r: 0.35, g: 0.55, b: 1.0), GradientStop(r: 0.55, g: 0.35, b: 1.0)]
        case .junkCleaner:
            return [GradientStop(r: 0.2, g: 0.75, b: 1.0), GradientStop(r: 0.35, g: 0.55, b: 1.0)]
        case .uninstaller:
            return [GradientStop(r: 1.0, g: 0.45, b: 0.45), GradientStop(r: 1.0, g: 0.3, b: 0.6)]
        case .largeFiles:
            return [GradientStop(r: 1.0, g: 0.65, b: 0.2), GradientStop(r: 1.0, g: 0.45, b: 0.3)]
        case .duplicates:
            return [GradientStop(r: 0.6, g: 0.35, b: 1.0), GradientStop(r: 0.85, g: 0.35, b: 0.9)]
        case .memory:
            return [GradientStop(r: 0.2, g: 0.85, b: 0.5), GradientStop(r: 0.15, g: 0.65, b: 0.85)]
        case .startup:
            return [GradientStop(r: 1.0, g: 0.8, b: 0.2), GradientStop(r: 1.0, g: 0.55, b: 0.2)]
        case .diskUsage:
            return [GradientStop(r: 0.35, g: 0.75, b: 1.0), GradientStop(r: 0.55, g: 0.35, b: 1.0)]
        case .shredder:
            return [GradientStop(r: 0.9, g: 0.3, b: 0.3), GradientStop(r: 0.7, g: 0.2, b: 0.2)]
        case .toolkit:
            return [GradientStop(r: 0.5, g: 0.5, b: 0.55), GradientStop(r: 0.35, g: 0.35, b: 0.4)]
        }
    }
}

struct GradientStop {
    let r: Double, g: Double, b: Double
}
