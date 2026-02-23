//
//  Cleankeun — macOS System Cleaner & Optimizer
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
    /// For browser cache items, identifies the source browser (e.g. "Safari", "Chrome")
    let browserApp: BrowserApp?
    var isSelected: Bool = true

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    init(path: String, size: Int64, category: JunkCategory, browserApp: BrowserApp? = nil, isSelected: Bool = true) {
        self.path = path
        self.size = size
        self.category = category
        self.browserApp = browserApp
        self.isSelected = isSelected
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: JunkItem, rhs: JunkItem) -> Bool { lhs.id == rhs.id && lhs.isSelected == rhs.isSelected }
}

/// Known browser apps for per-browser cache grouping
enum BrowserApp: String, CaseIterable, Identifiable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case firefox = "Firefox"
    case arc = "Arc"
    case brave = "Brave Browser"
    case edge = "Microsoft Edge"
    case opera = "Opera"

    var id: String { rawValue }

    /// Path to the .app bundle for icon retrieval
    var appPath: String {
        switch self {
        case .safari: return "/Applications/Safari.app"
        case .chrome: return "/Applications/Google Chrome.app"
        case .firefox: return "/Applications/Firefox.app"
        case .arc: return "/Applications/Arc.app"
        case .brave: return "/Applications/Brave Browser.app"
        case .edge: return "/Applications/Microsoft Edge.app"
        case .opera: return "/Applications/Opera.app"
        }
    }

    /// System image fallback if app is not installed
    var fallbackIcon: String {
        switch self {
        case .safari: return "safari.fill"
        case .chrome: return "globe"
        case .firefox: return "flame.fill"
        case .arc: return "globe"
        case .brave: return "shield.fill"
        case .edge: return "globe"
        case .opera: return "globe"
        }
    }
}

enum JunkCategory: String, CaseIterable, Identifiable {
    // Order matches BuhoCleaner's Flash Clean panel
    case purgeableSpace = "Purgeable Space"
    case systemCache = "System Cache Files"
    case userCache = "User Cache Files"
    case xcode = "Xcode Junk"
    case browserCache = "Browser Cache"
    case systemLogs = "System Log Files"
    case crashReports = "Crash Reports"
    case unusedDMGs = "Unused DMG Files"
    case userLogs = "User Log Files"
    case trashCan = "Trash Can"
    case downloads = "Downloads"
    case screenCaptures = "Screen Capture Files"
    case mailAttachments = "Mail Attachments"
    case iOSBackups = "iOS Backups"

    var id: String { rawValue }

    /// Categories that are safe to auto-select for cleaning ("smart selection").
    /// Only caches and logs — data that apps/system will regenerate.
    var isSafeToAutoSelect: Bool {
        switch self {
        case .systemCache, .userCache, .systemLogs, .userLogs, .crashReports, .purgeableSpace:
            return true
        default:
            return false
        }
    }

    /// Whether this category represents a virtual/special item (not normal file deletion)
    var isVirtual: Bool {
        self == .purgeableSpace
    }

    var icon: String {
        switch self {
        case .purgeableSpace: return "internaldrive.fill"
        case .systemCache: return "gearshape.2.fill"
        case .userCache: return "square.grid.3x3.fill"
        case .xcode: return "hammer.fill"
        case .browserCache: return "safari.fill"
        case .systemLogs: return "doc.text.fill"
        case .crashReports: return "exclamationmark.triangle.fill"
        case .unusedDMGs: return "opticaldiscdrive.fill"
        case .userLogs: return "doc.text.fill"
        case .trashCan: return "trash.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .screenCaptures: return "camera.viewfinder"
        case .mailAttachments: return "envelope.fill"
        case .iOSBackups: return "iphone"
        }
    }

    /// BuhoCleaner-style grouped color scheme
    var color: (r: Double, g: Double, b: Double) {
        switch self {
        // System group — blues
        case .purgeableSpace: return (0.50, 0.50, 0.55)
        case .systemCache: return (0.30, 0.55, 0.90)
        case .systemLogs: return (0.35, 0.60, 0.85)
        case .crashReports: return (0.40, 0.55, 0.85)
        // User group — teals
        case .userCache: return (0.20, 0.68, 0.65)
        case .xcode: return (0.22, 0.62, 0.72)
        case .userLogs: return (0.25, 0.65, 0.80)
        case .mailAttachments: return (0.25, 0.70, 0.58)
        case .iOSBackups: return (0.18, 0.65, 0.70)
        // Browser group — indigo
        case .browserCache: return (0.40, 0.38, 0.82)
        // Disk/Files — warm tones
        case .unusedDMGs: return (0.55, 0.50, 0.75)
        case .trashCan: return (0.60, 0.45, 0.45)
        case .downloads: return (0.30, 0.70, 0.95)
        case .screenCaptures: return (0.85, 0.55, 0.25)
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
    var lastUsedDate: Date?
    var isBundleSelected: Bool = false
    var isSelected: Bool {
        get { isBundleSelected || relatedFiles.contains { $0.isSelected } }
        set {
            isBundleSelected = newValue
            for i in relatedFiles.indices { relatedFiles[i].isSelected = newValue }
        }
    }

    var selectedSize: Int64 {
        (isBundleSelected ? size : 0) + relatedFiles.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

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
    var isSelected: Bool = false

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
    case library = "Library"
    case other = "Other"

    var group: AppComponentGroup {
        switch self {
        case .preferences: return .preferences
        case .cache: return .caches
        case .logs, .webKit, .library: return .library
        case .applicationSupport, .container, .savedState, .other: return .supportingFiles
        }
    }
}

enum AppComponentGroup: String, CaseIterable, Identifiable {
    case bundle = "Bundle"
    case library = "Library"
    case supportingFiles = "Supporting Files"
    case caches = "Caches"
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
        case "zip", "tar", "gz", "rar", "7z", "bz2", "xz", "jar", "bin", "pkg", "deb", "rpm", "cab", "ipa", "apk": return .archive
        case "dmg", "iso", "app": return .diskImage
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

    var isApple: Bool {
        if let bid = bundleIdentifier {
            return bid.hasPrefix("com.apple")
        }
        return path.contains("/System/") || path.contains("/usr/libexec/")
    }

    var vendorLabel: String {
        isApple ? "Apple" : "Third Party"
    }

    var impact: StartupImpact {
        // Heuristic: daemons are higher impact than agents, login items are medium
        switch type {
        case .launchDaemon: return .high
        case .launchAgent: return isApple ? .low : .medium
        case .loginItem: return .medium
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: StartupItem, rhs: StartupItem) -> Bool { lhs.id == rhs.id }
}

enum StartupType: String, CaseIterable, Identifiable {
    case launchAgent = "Launch Agent"
    case launchDaemon = "Launch Daemon"
    case loginItem = "Login Item"

    var id: String { rawValue }
}

enum StartupImpact: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .high: return (0.9, 0.3, 0.3)
        case .medium: return (1.0, 0.6, 0.2)
        case .low: return (0.3, 0.8, 0.4)
        }
    }
}

// MARK: - Storage Category (Feature 7 — matches macOS System Settings)
enum StorageCategory: String, CaseIterable, Identifiable {
    case applications = "Applications"
    case developer = "Developer"
    case documents = "Documents"
    case media = "Photos & Media"
    case mail = "Mail"
    case macOS = "macOS"
    case systemData = "System Data"
    case trash = "Trash"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .applications: return "app.fill"
        case .developer: return "hammer.fill"
        case .documents: return "doc.fill"
        case .media: return "photo.on.rectangle.fill"
        case .mail: return "envelope.fill"
        case .macOS: return "applelogo"
        case .systemData: return "externaldrive.fill"
        case .trash: return "trash.fill"
        case .other: return "questionmark.folder.fill"
        }
    }

    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .applications: return (0.35, 0.55, 1.0)
        case .developer: return (1.0, 0.6, 0.2)
        case .documents: return (0.55, 0.35, 1.0)
        case .media: return (0.9, 0.3, 0.5)
        case .mail: return (0.25, 0.65, 0.90)
        case .macOS: return (0.55, 0.55, 0.60)
        case .systemData: return (0.70, 0.70, 0.72)
        case .trash: return (0.50, 0.50, 0.55)
        case .other: return (0.4, 0.8, 0.4)
        }
    }
}

struct StorageCategoryInfo: Identifiable {
    let category: StorageCategory
    let size: Int64
    /// Top-level sub-paths contributing to this category (for expandable detail)
    var subPaths: [(name: String, size: Int64)]

    var id: String { category.id }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    init(category: StorageCategory, size: Int64, subPaths: [(name: String, size: Int64)] = []) {
        self.category = category
        self.size = size
        self.subPaths = subPaths
    }
}

// MARK: - Disk Usage
struct DiskUsageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    var children: [DiskUsageItem]
    let isDirectory: Bool
    var itemCount: Int = 0
    var isSelected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiskUsageItem, rhs: DiskUsageItem) -> Bool {
        lhs.id == rhs.id
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
enum NavigationSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cleaning = "Cleaning"
    case system = "System"
    case tools = "Tools"

    var id: String { rawValue }
}

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

    var section: NavigationSection {
        switch self {
        case .dashboard: return .overview
        case .junkCleaner, .uninstaller, .largeFiles, .duplicates: return .cleaning
        case .memory, .startup, .diskUsage: return .system
        case .shredder, .toolkit: return .tools
        }
    }

    static func items(for section: NavigationSection) -> [NavigationItem] {
        allCases.filter { $0.section == section }
    }

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

// MARK: - Sort Options
enum LargeFileSortOption: String, CaseIterable, Identifiable {
    case size = "Size"
    case name = "Name"
    case date = "Date Modified"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .size: return "arrow.up.arrow.down.square"
        case .name: return "textformat.abc"
        case .date: return "calendar"
        }
    }
}

enum AppSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case date = "Date"

    var id: String { rawValue }
}
