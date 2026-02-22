//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class AppViewModel {
    var selectedNav: NavigationItem = .dashboard
    var isScanning = false
    var scanProgress: Double = 0
    var statusMessage = "Ready"

    // Cleaning progress
    var isCleaning = false
    var cleaningProgress: Double = 0
    var cleaningCurrentFile = ""
    var cleaningFreedSoFar: Int64 = 0

    // Dashboard
    var diskTotal: Int64 = 0
    var diskUsed: Int64 = 0
    var diskFree: Int64 = 0
    var memoryInfo: MemoryInfo?
    var cpuInfo: CPUInfo?
    var networkInfo: NetworkInfo?

    // Junk
    var junkItems: [JunkItem] = []
    var junkByCategory: [JunkCategory: [JunkItem]] = [:]
    var totalJunkSize: Int64 = 0

    // Apps
    var installedApps: [InstalledApp] = []
    var appSearchText = ""
    var leftovers: [RelatedFile] = []

    // Large Files
    var largeFiles: [LargeFile] = []
    var allScannedLargeFiles: [LargeFile] = []  // full unfiltered results
    var largeFileMinSize: Int64 = 50 * 1024 * 1024 {
        didSet { applyLargeFileFilters() }
    }
    var largeFileFilter: LargeFileType? = nil {
        didSet { applyLargeFileFilters() }
    }

    // Duplicates
    var duplicateGroups: [DuplicateGroup] = []
    var totalDuplicatesSize: Int64 = 0

    // Startup
    var startupItems: [StartupItem] = []

    // Disk Usage
    var diskUsageItems: [DiskUsageItem] = []
    var currentDiskPath: String = NSHomeDirectory()

    // Shredder
    var shredItems: [ShredItem] = []

    // Monitor task handle for structured concurrency
    private var monitorTask: Task<Void, Never>?
    private var monitorRefCount = 0

    var filteredApps: [InstalledApp] {
        if appSearchText.isEmpty { return installedApps }
        return installedApps.filter { $0.name.localizedStandardContains(appSearchText) }
    }

    var selectedJunkSize: Int64 { junkItems.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    var selectedJunkCount: Int { junkItems.filter(\.isSelected).count }

    // MARK: - Monitor (H8: Use structured concurrency instead of Timer)
    func startMonitoring() {
        monitorRefCount += 1
        guard monitorTask == nil else { return }
        refreshSystemInfo()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                self?.refreshSystemInfo()
            }
        }
    }

    func stopMonitoring() {
        monitorRefCount = max(monitorRefCount - 1, 0)
        guard monitorRefCount == 0 else { return }
        monitorTask?.cancel()
        monitorTask = nil
    }

    func refreshSystemInfo() {
        let disk = SystemMonitorService.shared.getDiskInfo()
        diskTotal = disk.total
        diskUsed = disk.used
        diskFree = disk.free
        memoryInfo = MemoryService.shared.getMemoryInfo()
        cpuInfo = SystemMonitorService.shared.getCPUInfo()
        networkInfo = SystemMonitorService.shared.getNetworkSpeed()
    }

    // MARK: - Junk Cleaner
    func scanJunk() async {
        isScanning = true; scanProgress = 0
        statusMessage = "Scanning for junk files..."
        let items = await JunkCleanerService.shared.scanForJunk()
        junkItems = items
        totalJunkSize = items.reduce(0) { $0 + $1.size }
        var grouped: [JunkCategory: [JunkItem]] = [:]
        for item in items { grouped[item.category, default: []].append(item) }
        junkByCategory = grouped
        isScanning = false; scanProgress = 1.0
        statusMessage = "Found \(items.count) junk files (\(ByteCountFormatter.string(fromByteCount: totalJunkSize, countStyle: .file)))"
    }

    func cleanJunk() async {
        isCleaning = true
        cleaningProgress = 0
        cleaningCurrentFile = ""
        cleaningFreedSoFar = 0
        statusMessage = "Cleaning..."

        let itemsToClean = junkItems
        let result = await Task.detached { [weak self] () -> (deleted: Int, freedSpace: Int64, errors: [String]) in
            return JunkCleanerService.shared.cleanItemsWithProgress(itemsToClean) { current, total, freed, fileName in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.cleaningProgress = total > 0 ? Double(current) / Double(total) : 0
                    self.cleaningCurrentFile = fileName
                    self.cleaningFreedSoFar = freed
                }
            }
        }.value

        let cleanMsg = "Cleaned \(result.deleted) files, freed \(ByteCountFormatter.string(fromByteCount: result.freedSpace, countStyle: .file))"
        await scanJunk()
        statusMessage = cleanMsg
        isCleaning = false
        cleaningProgress = 1.0
    }

    func toggleAllJunk(selected: Bool) {
        junkItems = junkItems.map { var i = $0; i.isSelected = selected; return i }
        rebuildJunkCategories()
    }

    func toggleJunkCategory(_ category: JunkCategory, selected: Bool) {
        junkItems = junkItems.map { var i = $0; if i.category == category { i.isSelected = selected }; return i }
        rebuildJunkCategories()
    }

    func toggleJunkItem(_ item: JunkItem) {
        if let idx = junkItems.firstIndex(where: { $0.id == item.id }) {
            junkItems[idx].isSelected.toggle()
            rebuildJunkCategories()
        }
    }

    private func rebuildJunkCategories() {
        var grouped: [JunkCategory: [JunkItem]] = [:]
        for item in junkItems { grouped[item.category, default: []].append(item) }
        junkByCategory = grouped
    }

    // MARK: - Apps
    func scanApps() async {
        isScanning = true; statusMessage = "Scanning applications..."
        installedApps = await AppUninstallerService.shared.scanInstalledApps()
        leftovers = await AppUninstallerService.shared.scanLeftovers()
        isScanning = false
        statusMessage = "Found \(installedApps.count) apps, \(leftovers.count) leftovers"
    }

    func uninstallApp(_ app: InstalledApp) async {
        isScanning = true; statusMessage = "Uninstalling \(app.name)..."
        let result = AppUninstallerService.shared.uninstallApp(app)
        statusMessage = result.success ? "\(app.name) moved to Trash" : "Failed"
        if result.success { await scanApps() }
        isScanning = false
    }

    // MARK: - Large Files
    func scanLargeFiles() async {
        isScanning = true; statusMessage = "Scanning large files..."
        // Scan ALL files >= 1MB with no type filter — store full results
        allScannedLargeFiles = await LargeFileScannerService.shared.scanLargeFiles(minimumSize: 1 * 1024 * 1024, fileType: nil)
        applyLargeFileFilters()
        isScanning = false
        let total = largeFiles.reduce(0) { $0 + $1.size }
        statusMessage = "Found \(largeFiles.count) files (\(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)))"
    }

    /// Filters `allScannedLargeFiles` by current `largeFileMinSize` and `largeFileFilter`,
    /// storing the result in `largeFiles` for display.
    func applyLargeFileFilters() {
        largeFiles = allScannedLargeFiles.filter { file in
            if file.size < largeFileMinSize { return false }
            if let typeFilter = largeFileFilter, file.fileType != typeFilter { return false }
            return true
        }
    }

    func deleteLargeFiles() async {
        isScanning = true
        let result = LargeFileScannerService.shared.deleteFiles(largeFiles)
        let deleteMsg = "Freed \(ByteCountFormatter.string(fromByteCount: result.freedSpace, countStyle: .file))"
        // Remove deleted files from allScannedLargeFiles too
        let deletedPaths = Set(largeFiles.filter(\.isSelected).map(\.path))
        allScannedLargeFiles.removeAll { deletedPaths.contains($0.path) }
        applyLargeFileFilters()
        statusMessage = deleteMsg
        isScanning = false
    }

    // MARK: - Duplicates
    func scanDuplicates() async {
        isScanning = true; statusMessage = "Finding duplicates..."
        duplicateGroups = await DuplicateFinderService.shared.scanForDuplicates()
        totalDuplicatesSize = duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
        isScanning = false
        statusMessage = "Found \(duplicateGroups.count) groups (\(ByteCountFormatter.string(fromByteCount: totalDuplicatesSize, countStyle: .file)) wasted)"
    }

    func deleteDuplicates() async {
        isScanning = true
        let all = duplicateGroups.flatMap(\.files).filter(\.isSelected)
        let result = DuplicateFinderService.shared.deleteFiles(all)
        let deleteMsg = "Freed \(ByteCountFormatter.string(fromByteCount: result.freedSpace, countStyle: .file))"
        await scanDuplicates()
        statusMessage = deleteMsg
        isScanning = false
    }

    // MARK: - Memory
    func optimizeMemory() async {
        isScanning = true; statusMessage = "Optimizing memory..."
        let result = await MemoryService.shared.optimizeMemory()
        memoryInfo = result.after
        let freed = Int64(result.before.used) - Int64(result.after.used)
        statusMessage = freed > 0 ? "Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .memory))" : "Memory optimized"
        isScanning = false
    }

    // MARK: - Startup
    func scanStartupItems() {
        startupItems = StartupManagerService.shared.scanStartupItems()
        statusMessage = "\(startupItems.count) startup items found"
    }

    func toggleStartupItem(at index: Int) async {
        guard index < startupItems.count else { return }
        if await StartupManagerService.shared.toggleStartupItem(startupItems[index]) {
            startupItems[index].isEnabled.toggle()
        }
    }

    // MARK: - Disk Usage
    func analyzeDiskUsage() async {
        isScanning = true; statusMessage = "Analyzing disk..."
        diskUsageItems = await DiskUsageService.shared.analyzeDiskUsage(path: currentDiskPath)
        isScanning = false; statusMessage = "Analysis complete"
    }

    func navigateDiskUsage(to path: String) async {
        currentDiskPath = path
        await analyzeDiskUsage()
    }

    // MARK: - Shredder
    func addShredItem(url: URL) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        let size: Int64
        if isDir.boolValue {
            size = directorySize(path: url.path)
        } else {
            size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
        }
        shredItems.append(ShredItem(path: url.path, size: size, isDirectory: isDir.boolValue))
    }

    func shredAllItems(passes: Int = 3) async {
        isScanning = true; statusMessage = "Securely shredding files..."
        var errors: [String] = []
        for item in shredItems {
            do {
                try FileShredderService.shared.shredFile(at: item.path, passes: passes)
            } catch {
                errors.append("\(item.fileName): \(error.localizedDescription)")
            }
        }
        shredItems.removeAll()
        isScanning = false
        statusMessage = errors.isEmpty ? "All files securely shredded" : "Shredded with \(errors.count) errors"
    }

    private func directorySize(path: String) -> Int64 {
        var total: Int64 = 0
        if let e = FileManager.default.enumerator(atPath: path) {
            while let f = e.nextObject() as? String {
                let fp = (path as NSString).appendingPathComponent(f)
                if let s = (try? FileManager.default.attributesOfItem(atPath: fp))?[.size] as? Int64 { total += s }
            }
        }
        return total
    }
}
