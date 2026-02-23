//
//  Cleankeun — macOS System Cleaner & Optimizer
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

    // Scanning progress (for Flash Clean animated scan)
    var scanningCurrentPath = ""
    var scanningFilesFound = 0

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
    var trashAccessDenied: Bool = false

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
    var largeFileSortBy: LargeFileSortOption = .size {
        didSet { applyLargeFileFilters() }
    }
    var largeFileSortAscending: Bool = false {
        didSet { applyLargeFileFilters() }
    }

    // App sort
    var appSortBy: AppSortOption = .name

    // Duplicates
    var duplicateGroups: [DuplicateGroup] = []
    var totalDuplicatesSize: Int64 = 0

    // Startup
    var startupItems: [StartupItem] = []

    // Disk Usage
    var diskUsageItems: [DiskUsageItem] = []
    var currentDiskPath: String = NSHomeDirectory()
    var availableVolumes: [VolumeInfo] = []
    private var diskUsageCache: [String: [DiskUsageItem]] = [:]

    // Shredder
    var shredItems: [ShredItem] = []

    // Duplicate scan scope (Feature 5)
    var duplicateScanPaths: [String: Bool] = {
        let home = NSHomeDirectory()
        return [
            "\(home)/Downloads": true,
            "\(home)/Desktop": true,
            "\(home)/Documents": true,
            "\(home)/Pictures": true,
            "\(home)/Movies": true,
            "\(home)/Music": true,
        ]
    }()
    var duplicateScanHidden: Bool = false

    // Storage categories (Feature 7)
    var storageCategories: [StorageCategoryInfo] = []
    private var storageScanInProgress = false

    // Monitor task handle for structured concurrency
    private var monitorTask: Task<Void, Never>?
    private var monitorRefCount = 0

    // MARK: - Health Score (Feature 2)
    /// System health score from 0-100. Higher = healthier.
    var systemHealthScore: Int {
        var score = 100

        // RAM pressure penalty (0-40 points)
        if let mem = memoryInfo {
            let ramPct = mem.usagePercentage
            if ramPct > 90 { score -= 40 }
            else if ramPct > 80 { score -= 25 }
            else if ramPct > 70 { score -= 15 }
            else if ramPct > 60 { score -= 5 }
        }

        // Disk usage penalty (0-35 points)
        if diskTotal > 0 {
            let diskPct = Double(diskUsed) / Double(diskTotal) * 100
            if diskPct > 95 { score -= 35 }
            else if diskPct > 90 { score -= 25 }
            else if diskPct > 85 { score -= 15 }
            else if diskPct > 75 { score -= 5 }
        }

        // CPU load penalty (0-25 points)
        if let cpu = cpuInfo {
            if cpu.usagePercentage > 90 { score -= 25 }
            else if cpu.usagePercentage > 70 { score -= 15 }
            else if cpu.usagePercentage > 50 { score -= 8 }
        }

        return max(0, min(100, score))
    }

    var healthScoreColor: (r: Double, g: Double, b: Double) {
        if systemHealthScore >= 80 { return (0.3, 0.8, 0.4) }  // Green
        if systemHealthScore >= 50 { return (1.0, 0.7, 0.2) }  // Yellow/Orange
        return (0.9, 0.3, 0.3)  // Red
    }

    var healthRecommendations: [(icon: String, text: String)] {
        var recs: [(String, String)] = []
        if let mem = memoryInfo, mem.usagePercentage > 75 {
            recs.append(("memorychip", "High RAM usage (\(Int(mem.usagePercentage))%) — consider freeing memory"))
        }
        if diskTotal > 0 {
            let diskPct = Double(diskUsed) / Double(diskTotal) * 100
            if diskPct > 80 {
                recs.append(("internaldrive", "Disk is \(Int(diskPct))% full — run Flash Clean or remove large files"))
            }
        }
        if let cpu = cpuInfo, cpu.usagePercentage > 70 {
            recs.append(("cpu", "CPU load is high (\(Int(cpu.usagePercentage))%) — check running processes"))
        }
        if totalJunkSize > 500 * 1024 * 1024 {
            recs.append(("trash", "Over 500 MB of junk detected — run Flash Clean"))
        }
        if recs.isEmpty {
            recs.append(("checkmark.seal.fill", "System is running smoothly!"))
        }
        return recs
    }

    // MARK: - Storage Categories (Feature 7 — macOS System Settings style)
    /// Public entry point — dispatches to background. Safe to call from MainActor.
    func scanStorageCategories() {
        guard !storageScanInProgress else { return }
        storageScanInProgress = true
        Task.detached { [weak self] in
            guard let self else { return }
            let diskUsed = await self.diskUsed
            let categories = Self.computeStorageCategories(diskUsed: diskUsed)
            await MainActor.run {
                self.storageCategories = categories
                self.storageScanInProgress = false
            }
        }
    }

    /// Heavy work — runs off main thread. Mimics macOS System Settings categories.
    nonisolated private static func computeStorageCategories(diskUsed: Int64) -> [StorageCategoryInfo] {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        var results: [StorageCategoryInfo] = []
        var accountedSize: Int64 = 0

        // 1. Applications — /Applications + ~/Applications
        let appPaths = ["/Applications", "\(home)/Applications"]
        var appTotal: Int64 = 0
        var appSubs: [(String, Int64)] = []
        for path in appPaths {
            let s = directorySizeSync(path: path)
            if s > 0 {
                appSubs.append(((path as NSString).lastPathComponent, s))
                appTotal += s
            }
        }
        results.append(StorageCategoryInfo(category: .applications, size: appTotal, subPaths: appSubs))
        accountedSize += appTotal

        // 2. Developer — ~/Library/Developer + ~/Developer
        let devPaths = ["\(home)/Library/Developer", "\(home)/Developer"]
        var devTotal: Int64 = 0
        var devSubs: [(String, Int64)] = []
        for path in devPaths {
            let s = directorySizeSync(path: path)
            if s > 0 {
                // Show sub-directories for detail
                if let contents = try? fm.contentsOfDirectory(atPath: path) {
                    for sub in contents.prefix(10) {
                        let subPath = (path as NSString).appendingPathComponent(sub)
                        let subSize = directorySizeSync(path: subPath)
                        if subSize > 10_000_000 { // > 10MB
                            devSubs.append((sub, subSize))
                        }
                    }
                }
                devTotal += s
            }
        }
        devSubs.sort { $0.1 > $1.1 }
        results.append(StorageCategoryInfo(category: .developer, size: devTotal, subPaths: devSubs))
        accountedSize += devTotal

        // 3. Documents — ~/Documents, ~/Desktop, ~/Downloads
        let docPaths = ["\(home)/Documents", "\(home)/Desktop", "\(home)/Downloads"]
        var docTotal: Int64 = 0
        var docSubs: [(String, Int64)] = []
        for path in docPaths {
            let s = directorySizeSync(path: path)
            if s > 0 {
                docSubs.append(((path as NSString).lastPathComponent, s))
                docTotal += s
            }
        }
        results.append(StorageCategoryInfo(category: .documents, size: docTotal, subPaths: docSubs))
        accountedSize += docTotal

        // 4. Photos & Media — ~/Pictures, ~/Movies, ~/Music
        let mediaPaths = ["\(home)/Pictures", "\(home)/Movies", "\(home)/Music"]
        var mediaTotal: Int64 = 0
        var mediaSubs: [(String, Int64)] = []
        for path in mediaPaths {
            let s = directorySizeSync(path: path)
            if s > 0 {
                mediaSubs.append(((path as NSString).lastPathComponent, s))
                mediaTotal += s
            }
        }
        results.append(StorageCategoryInfo(category: .media, size: mediaTotal, subPaths: mediaSubs))
        accountedSize += mediaTotal

        // 5. Mail — ~/Library/Mail
        let mailPath = "\(home)/Library/Mail"
        let mailSize = directorySizeSync(path: mailPath)
        if mailSize > 0 {
            results.append(StorageCategoryInfo(category: .mail, size: mailSize, subPaths: [("Mail Data", mailSize)]))
            accountedSize += mailSize
        }

        // 6. Trash — ~/.Trash
        let trashPath = "\(home)/.Trash"
        let trashSize = directorySizeSync(path: trashPath)
        if trashSize > 0 {
            results.append(StorageCategoryInfo(category: .trash, size: trashSize, subPaths: [("Trash Items", trashSize)]))
            accountedSize += trashSize
        }

        // 7. macOS — system volumes (Macintosh HD, VM, Preboot, Recovery)
        // Parse from diskutil to get accurate system volume sizes
        var macOSSize: Int64 = 0
        var macOSSubs: [(String, Int64)] = []
        let volumeNames = [
            ("disk3s1", "macOS Volume"),
            ("disk3s6", "VM Swap"),
            ("disk3s2", "Preboot"),
            ("disk3s3", "Recovery"),
        ]
        for (disk, label) in volumeNames {
            let size = Self.diskutilVolumeUsedSpace(disk: disk)
            if size > 0 {
                macOSSubs.append((label, size))
                macOSSize += size
            }
        }
        if macOSSize > 0 {
            results.append(StorageCategoryInfo(category: .macOS, size: macOSSize, subPaths: macOSSubs))
            accountedSize += macOSSize
        }

        // 8. System Data — ~/Library (minus Developer, minus Mail) + caches/support
        let librarySize = directorySizeSync(path: "\(home)/Library")
        let systemDataSize = max(0, librarySize - devTotal - mailSize)
        var sysSubs: [(String, Int64)] = []
        // Show top sub-directories of ~/Library
        let libSubDirs = ["Caches", "Application Support", "Containers", "Group Containers", "Logs", "Saved Application State"]
        for sub in libSubDirs {
            let subPath = "\(home)/Library/\(sub)"
            let subSize = directorySizeSync(path: subPath)
            if subSize > 10_000_000 { // > 10MB
                sysSubs.append((sub, subSize))
            }
        }
        sysSubs.sort { $0.1 > $1.1 }
        results.append(StorageCategoryInfo(category: .systemData, size: systemDataSize, subPaths: sysSubs))
        accountedSize += systemDataSize

        // 9. Other — remaining used space not accounted for
        let otherSize = max(0, diskUsed - accountedSize)
        if otherSize > 10_000_000 { // Only show if > 10MB
            results.append(StorageCategoryInfo(category: .other, size: otherSize, subPaths: []))
        }

        return results.filter { $0.size > 0 }.sorted { $0.size > $1.size }
    }

    /// Parse `diskutil info <disk>` to get Volume Used Space in bytes
    nonisolated private static func diskutilVolumeUsedSpace(disk: String) -> Int64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", disk]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for "Volume Used Space:" line with bytes in parentheses
                for line in output.components(separatedBy: "\n") {
                    if line.contains("Volume Used Space") || line.contains("Container Free Space") {
                        // Parse bytes from "(12345678 Bytes)"
                        if let range = line.range(of: "("),
                           let endRange = line.range(of: " Bytes)") {
                            let bytesStr = String(line[range.upperBound..<endRange.lowerBound])
                            if let bytes = Int64(bytesStr) {
                                return bytes
                            }
                        }
                    }
                }
            }
        } catch {
            // Ignore — will return 0
        }
        return 0
    }

    var filteredApps: [InstalledApp] {
        var apps: [InstalledApp]
        if appSearchText.isEmpty {
            apps = installedApps
        } else {
            apps = installedApps.filter { $0.name.localizedStandardContains(appSearchText) }
        }
        switch appSortBy {
        case .name:
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            apps.sort { $0.totalSize > $1.totalSize }
        case .date:
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending } // fallback, no date available
        }
        return apps
    }

    var selectedJunkSize: Int64 = 0
    var selectedJunkCount: Int = 0

    func updateJunkSelection() {
        var size: Int64 = 0
        var count = 0
        for item in junkItems where item.isSelected {
            size += item.size
            count += 1
        }
        selectedJunkSize = size
        selectedJunkCount = count
    }

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
        // Scan storage categories lazily in the background (only once)
        if storageCategories.isEmpty && !storageScanInProgress {
            storageScanInProgress = true
            Task.detached { [weak self] in
                guard let self else { return }
                let used = await self.diskUsed
                let categories = Self.computeStorageCategories(diskUsed: used)
                await MainActor.run {
                    self.storageCategories = categories
                    self.storageScanInProgress = false
                }
            }
        }
    }

    // MARK: - Junk Cleaner
    func scanJunk() async {
        isScanning = true; scanProgress = 0
        scanningCurrentPath = ""
        scanningFilesFound = 0
        statusMessage = "Scanning for junk files..."

        let scanResult = await Task.detached { [weak self] () -> JunkCleanerService.ScanResult in
            return await JunkCleanerService.shared.scanForJunk { path, count in
                Task { @MainActor in
                    self?.scanningCurrentPath = path
                    self?.scanningFilesFound = count
                }
            }
        }.value

        let items = scanResult.items
        trashAccessDenied = scanResult.trashAccessDenied
        junkItems = items
        totalJunkSize = items.reduce(0) { $0 + $1.size }
        var grouped: [JunkCategory: [JunkItem]] = [:]
        for item in items { grouped[item.category, default: []].append(item) }
        junkByCategory = grouped
        updateJunkSelection()
        isScanning = false; scanProgress = 1.0
        scanningCurrentPath = ""
        statusMessage = "Found \(items.count) junk files (\(ByteCountFormatter.string(fromByteCount: totalJunkSize, countStyle: .file)))"
    }

    func cleanJunk() async {
        isCleaning = true
        cleaningProgress = 0
        cleaningCurrentFile = ""
        cleaningFreedSoFar = 0
        statusMessage = "Permanently deleting files..."

        let itemsToClean = junkItems
        let hasPurgeable = itemsToClean.contains { $0.category == .purgeableSpace && $0.isSelected }
        
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
        
        var totalFreed = result.freedSpace
        
        if hasPurgeable {
            statusMessage = "Freeing purgeable space..."
            cleaningCurrentFile = "Freeing macOS purgeable space (this may take a minute)..."
            let purgeResult = await ToolkitService.shared.freePurgeableSpace { progress, message in
                Task { @MainActor in
                    self.cleaningProgress = progress
                    self.cleaningCurrentFile = message
                }
            }
            if purgeResult.success {
                let purgeableSize = itemsToClean.filter { $0.category == .purgeableSpace && $0.isSelected }.reduce(0) { $0 + $1.size }
                totalFreed += purgeableSize
            }
        }

        let cleanMsg = "Permanently deleted \(result.deleted) files, freed \(ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file))"
        await scanJunk()
        statusMessage = cleanMsg
        isCleaning = false
        cleaningProgress = 1.0
    }

    func toggleAllJunk(selected: Bool) {
        for i in junkItems.indices {
            junkItems[i].isSelected = selected
        }
        rebuildJunkCategories()
        updateJunkSelection()
    }

    func toggleJunkCategory(_ category: JunkCategory, selected: Bool) {
        for i in junkItems.indices where junkItems[i].category == category {
            junkItems[i].isSelected = selected
        }
        // Only rebuild the one category that changed
        junkByCategory[category] = junkItems.filter { $0.category == category }
        updateJunkSelection()
    }

    func toggleJunkItem(_ item: JunkItem) {
        guard let idx = junkItems.firstIndex(where: { $0.id == item.id }) else { return }
        junkItems[idx].isSelected.toggle()
        // Only rebuild the category this item belongs to
        let cat = junkItems[idx].category
        junkByCategory[cat] = junkItems.filter { $0.category == cat }
        updateJunkSelection()
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
        statusMessage = result.success ? "\(app.name) removed" : "Failed"
        if result.success { await scanApps() }
        isScanning = false
    }

    func removeLeftovers(_ files: [RelatedFile]) async {
        isScanning = true; statusMessage = "Removing leftovers..."
        for file in files {
            try? FileManager.default.removeItem(atPath: file.path)
        }
        await scanApps()
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
    /// then sorts by the current sort option, storing the result in `largeFiles` for display.
    func applyLargeFileFilters() {
        var filtered = allScannedLargeFiles.filter { file in
            if file.size < largeFileMinSize { return false }
            if let typeFilter = largeFileFilter, file.fileType != typeFilter { return false }
            return true
        }

        // Apply sorting
        switch largeFileSortBy {
        case .size:
            filtered.sort { largeFileSortAscending ? $0.size < $1.size : $0.size > $1.size }
        case .name:
            filtered.sort { largeFileSortAscending ? $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending : $0.fileName.localizedStandardCompare($1.fileName) == .orderedDescending }
        case .date:
            filtered.sort { largeFileSortAscending ? $0.modificationDate < $1.modificationDate : $0.modificationDate > $1.modificationDate }
        }

        largeFiles = filtered
    }

    func deleteLargeFiles() async {
        isScanning = true
        let result = LargeFileScannerService.shared.deleteFiles(largeFiles)
        let deleteMsg = "Permanently deleted \(result.deleted) files, freed \(ByteCountFormatter.string(fromByteCount: result.freedSpace, countStyle: .file))"
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
        let paths = duplicateScanPaths.filter { $0.value }.map { $0.key }
        duplicateGroups = await DuplicateFinderService.shared.scanForDuplicates(paths: paths, includeHidden: duplicateScanHidden)
        totalDuplicatesSize = duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
        isScanning = false
        statusMessage = "Found \(duplicateGroups.count) groups (\(ByteCountFormatter.string(fromByteCount: totalDuplicatesSize, countStyle: .file)) wasted)"
    }

    func deleteDuplicates() async {
        isScanning = true
        let all = duplicateGroups.flatMap(\.files).filter(\.isSelected)
        let result = DuplicateFinderService.shared.deleteFiles(all)
        let deleteMsg = "Permanently deleted \(result.deleted) duplicates, freed \(ByteCountFormatter.string(fromByteCount: result.freedSpace, countStyle: .file))"
        await scanDuplicates()
        statusMessage = deleteMsg
        isScanning = false
    }

    /// Smart Select: for each duplicate group, select all copies except the first (original)
    func smartSelectDuplicates() {
        for gi in duplicateGroups.indices {
            for fi in duplicateGroups[gi].files.indices {
                duplicateGroups[gi].files[fi].isSelected = fi > 0
            }
        }
    }

    /// Deselect all duplicates
    func deselectAllDuplicates() {
        for gi in duplicateGroups.indices {
            for fi in duplicateGroups[gi].files.indices {
                duplicateGroups[gi].files[fi].isSelected = false
            }
        }
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
    func loadVolumes() {
        availableVolumes = DiskUsageService.shared.getAvailableVolumes()
    }

    func analyzeDiskUsage() async {
        isScanning = true; statusMessage = "Analyzing disk..."
        diskUsageItems = await DiskUsageService.shared.analyzeDiskUsage(path: currentDiskPath)
        diskUsageCache[currentDiskPath] = diskUsageItems
        isScanning = false; statusMessage = "Analysis complete"
    }

    func navigateDiskUsage(to path: String, withChildren children: [DiskUsageItem]? = nil) async {
        currentDiskPath = path
        if let children = children, !children.isEmpty {
            diskUsageItems = children
            diskUsageCache[path] = children
            return
        }
        if let cached = diskUsageCache[path] {
            diskUsageItems = cached
            return
        }
        await analyzeDiskUsage()
    }

    func deleteDiskItems(paths: Set<String>) async {
        isScanning = true
        statusMessage = "Deleting items..."
        
        var freedSpace: Int64 = 0
        var deletedCount = 0
        
        for path in paths {
            let item = diskUsageItems.first(where: { $0.path == path })
            do {
                try FileManager.default.removeItem(atPath: path)
                if let size = item?.size {
                    freedSpace += size
                }
                deletedCount += 1
            } catch {
                print("Failed to delete \(path): \(error.localizedDescription)")
            }
        }
        
        // Refresh the current view
        diskUsageCache.removeValue(forKey: currentDiskPath)
        await analyzeDiskUsage()
        
        statusMessage = "Permanently deleted \(deletedCount) items, freed \(ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file))"
        isScanning = false
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
        Self.directorySizeSync(path: path)
    }

    nonisolated private static func directorySizeSync(path: String) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        while let url = enumerator.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
