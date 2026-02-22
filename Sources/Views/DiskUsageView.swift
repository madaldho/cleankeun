//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

// MARK: - Treemap Layout Algorithm (Squarified)

/// A positioned rectangle in the treemap, referencing a DiskUsageItem.
private struct TreemapRect: Identifiable {
    let id: UUID
    let item: DiskUsageItem
    let rect: CGRect
    let color: Color
}

/// Squarified treemap layout — produces near-square rectangles for better readability.
private struct TreemapLayout {

    /// File-type color palette — assigns a consistent color based on file extension or directory status.
    static func colorFor(item: DiskUsageItem, index: Int) -> Color {
        if item.isDirectory {
            let hues: [Color] = [
                Color(red: 0.30, green: 0.58, blue: 1.0),
                Color(red: 0.55, green: 0.40, blue: 0.95),
                Color(red: 0.20, green: 0.72, blue: 0.62),
                Color(red: 0.92, green: 0.52, blue: 0.22),
                Color(red: 0.32, green: 0.68, blue: 0.88),
                Color(red: 0.72, green: 0.32, blue: 0.62),
                Color(red: 0.42, green: 0.78, blue: 0.32),
                Color(red: 0.85, green: 0.42, blue: 0.42),
                Color(red: 0.95, green: 0.65, blue: 0.20),
                Color(red: 0.25, green: 0.65, blue: 0.75),
            ]
            return hues[index % hues.count]
        }

        // File type coloring by extension
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "app": return Color(red: 0.35, green: 0.55, blue: 1.0)
        case "dmg", "pkg", "zip", "tar", "gz", "rar", "7z":
            return Color(red: 0.9, green: 0.5, blue: 0.2)
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "svg", "ico", "tiff", "bmp":
            return Color(red: 0.9, green: 0.3, blue: 0.5)
        case "mp4", "mov", "avi", "mkv", "m4v", "webm", "wmv":
            return Color(red: 0.8, green: 0.2, blue: 0.4)
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "wma":
            return Color(red: 0.6, green: 0.2, blue: 0.8)
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key":
            return Color(red: 0.2, green: 0.6, blue: 0.4)
        case "swift", "py", "js", "ts", "c", "cpp", "h", "m", "rs", "go", "java", "rb":
            return Color(red: 0.3, green: 0.7, blue: 0.9)
        case "json", "xml", "yaml", "yml", "plist", "toml":
            return Color(red: 0.5, green: 0.7, blue: 0.3)
        case "log", "txt", "md", "csv":
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        default:
            return Color(red: 0.6, green: 0.6, blue: 0.65)
        }
    }

    /// Compute squarified treemap layout for given items within a bounding rect.
    static func layout(items: [DiskUsageItem], in bounds: CGRect) -> [TreemapRect] {
        guard !items.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }

        let totalSize = items.reduce(Int64(0)) { $0 + max($1.size, 1) }
        guard totalSize > 0 else { return [] }

        // Normalize sizes to areas proportional to the bounding rect
        let totalArea = Double(bounds.width * bounds.height)
        let areas: [(index: Int, item: DiskUsageItem, area: Double)] = items.enumerated().map { i, item in
            let area = (Double(max(item.size, 1)) / Double(totalSize)) * totalArea
            return (i, item, max(area, 1))
        }

        var result: [TreemapRect] = []
        squarify(areas: areas, remaining: bounds, result: &result)
        return result
    }

    /// Recursive squarified layout. Lays out rows of items trying to keep aspect ratios close to 1.
    private static func squarify(areas: [(index: Int, item: DiskUsageItem, area: Double)],
                                 remaining: CGRect,
                                 result: inout [TreemapRect]) {
        guard !areas.isEmpty else { return }
        if areas.count == 1 {
            let entry = areas[0]
            result.append(TreemapRect(
                id: entry.item.id,
                item: entry.item,
                rect: remaining,
                color: colorFor(item: entry.item, index: entry.index)
            ))
            return
        }

        let totalArea = areas.reduce(0.0) { $0 + $1.area }
        let isHorizontal = remaining.width >= remaining.height
        let sideLength = isHorizontal ? Double(remaining.height) : Double(remaining.width)

        // Greedily add items to current row while aspect ratio improves
        var rowItems: [(index: Int, item: DiskUsageItem, area: Double)] = []
        var rowArea = 0.0
        var bestWorst = Double.infinity

        for (i, entry) in areas.enumerated() {
            let candidateRow = rowItems + [entry]
            let candidateArea = rowArea + entry.area
            let worst = worstAspectRatio(row: candidateRow, rowArea: candidateArea, sideLength: sideLength)

            if worst <= bestWorst {
                rowItems = candidateRow
                rowArea = candidateArea
                bestWorst = worst
            } else {
                // Current row is optimal; lay it out and recurse on remainder
                let rowFraction = rowArea / totalArea
                let rowRect: CGRect
                let restRect: CGRect

                if isHorizontal {
                    let w = CGFloat(rowFraction) * remaining.width
                    rowRect = CGRect(x: remaining.minX, y: remaining.minY, width: w, height: remaining.height)
                    restRect = CGRect(x: remaining.minX + w, y: remaining.minY, width: remaining.width - w, height: remaining.height)
                } else {
                    let h = CGFloat(rowFraction) * remaining.height
                    rowRect = CGRect(x: remaining.minX, y: remaining.minY, width: remaining.width, height: h)
                    restRect = CGRect(x: remaining.minX, y: remaining.minY + h, width: remaining.width, height: remaining.height - h)
                }

                layoutRow(rowItems, in: rowRect, isHorizontal: isHorizontal, result: &result)
                squarify(areas: Array(areas[i...]), remaining: restRect, result: &result)
                return
            }
        }

        // All items fit in one row
        layoutRow(rowItems, in: remaining, isHorizontal: isHorizontal, result: &result)
    }

    /// Lay out a single row of items within the given rect.
    private static func layoutRow(_ items: [(index: Int, item: DiskUsageItem, area: Double)],
                                  in rect: CGRect,
                                  isHorizontal: Bool,
                                  result: inout [TreemapRect]) {
        let totalArea = items.reduce(0.0) { $0 + $1.area }
        guard totalArea > 0 else { return }

        var offset: CGFloat = 0
        for entry in items {
            let fraction = CGFloat(entry.area / totalArea)
            let itemRect: CGRect

            if isHorizontal {
                let h = fraction * rect.height
                itemRect = CGRect(x: rect.minX, y: rect.minY + offset, width: rect.width, height: h)
                offset += h
            } else {
                let w = fraction * rect.width
                itemRect = CGRect(x: rect.minX + offset, y: rect.minY, width: w, height: rect.height)
                offset += w
            }

            result.append(TreemapRect(
                id: entry.item.id,
                item: entry.item,
                rect: itemRect,
                color: colorFor(item: entry.item, index: entry.index)
            ))
        }
    }

    /// Worst (maximum) aspect ratio among items in a row — lower is better.
    private static func worstAspectRatio(row: [(index: Int, item: DiskUsageItem, area: Double)],
                                         rowArea: Double,
                                         sideLength: Double) -> Double {
        guard sideLength > 0, rowArea > 0 else { return .infinity }
        let rowLength = rowArea / sideLength
        guard rowLength > 0 else { return .infinity }

        var worst = 0.0
        for entry in row {
            let itemLength = entry.area / rowLength
            let ratio = max(itemLength / sideLength, sideLength / itemLength)
            worst = max(worst, ratio)
        }
        return worst
    }
}

// MARK: - Treemap Cell

private struct TreemapCell: View {
    let tr: TreemapRect
    let isHovered: Bool
    let onTap: () -> Void

    /// Real Finder icon for the file/folder
    private var finderIcon: NSImage {
        NSWorkspace.shared.icon(forFile: tr.item.path)
    }

    // Size thresholds for different display modes
    private var cellWidth: CGFloat { tr.rect.width }
    private var cellHeight: CGFloat { tr.rect.height }
    private var isLargeCell: Bool { cellWidth > 120 && cellHeight > 90 }
    private var isMediumCell: Bool { cellWidth > 70 && cellHeight > 55 }
    private var isSmallCell: Bool { cellWidth > 40 && cellHeight > 24 }

    /// Dynamic icon size based on cell dimensions
    private var iconSize: CGFloat {
        if isLargeCell { return min(36, min(cellWidth, cellHeight) * 0.35) }
        if isMediumCell { return min(24, min(cellWidth, cellHeight) * 0.3) }
        return 0
    }

    /// Dynamic font size for the name label
    private var nameFontSize: CGFloat {
        if isLargeCell { return min(12, max(9, cellWidth / 12)) }
        if isMediumCell { return min(10, max(8, cellWidth / 12)) }
        return max(7, min(9, cellWidth / 10))
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(tr.color.opacity(isHovered ? 0.85 : 0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.white.opacity(isHovered ? 0.5 : 0.15), lineWidth: 1)
                    )

                if isLargeCell || isMediumCell {
                    // Large/Medium: centered icon + name + size
                    VStack(spacing: isLargeCell ? 6 : 3) {
                        Image(nsImage: finderIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

                        Text(tr.item.name)
                            .font(.system(size: nameFontSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(isLargeCell ? 2 : 1)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                        if isLargeCell || cellHeight > 70 {
                            Text(tr.item.formattedSize)
                                .font(.system(size: max(8, nameFontSize - 2), weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        }
                    }
                    .padding(isLargeCell ? 8 : 4)
                    .frame(maxWidth: cellWidth - 4, maxHeight: cellHeight - 4)
                } else if isSmallCell {
                    // Small: just name, top-left aligned
                    Text(tr.item.name)
                        .font(.system(size: max(7, min(9, cellWidth / 10)), weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                // Tiny cells: no label at all
            }
            .frame(width: max(1, tr.rect.width - 1), height: max(1, tr.rect.height - 1))
            .offset(x: tr.rect.minX + 0.5, y: tr.rect.minY + 0.5)
        }
        .buttonStyle(.plain)
        .help("\(tr.item.name) — \(tr.item.formattedSize)\(tr.item.isDirectory ? " (folder)" : "")")
        .contextMenu {
            Button {
                NSWorkspace.shared.selectFile(tr.item.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            if tr.item.isDirectory {
                Button(action: onTap) {
                    Label("Browse Directory", systemImage: "arrow.right.circle")
                }
            }
        }
    }
}

// MARK: - DiskUsageView (BuhoCleaner-style split panel)

struct DiskUsageView: View {
    @Environment(AppViewModel.self) var vm
    @State private var selectedItemId: UUID? = nil
    @State private var hoveredTreemapId: UUID? = nil
    @State private var navigationHistory: [String] = []

    private var selectedItem: DiskUsageItem? {
        vm.diskUsageItems.first(where: { $0.id == selectedItemId })
    }

    private var totalSizeOfItems: Int64 {
        vm.diskUsageItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            topToolbar

            Divider()

            if vm.diskUsageItems.isEmpty && !vm.isScanning {
                emptyView
            } else {
                // Main content — split panel like BuhoCleaner
                HStack(spacing: 0) {
                    // Left panel — folder/file tree list
                    leftTreePanel
                    Divider()
                    // Right panel — treemap visualization + selected item info
                    rightVisualizationPanel
                }
            }
        }
        .onAppear { vm.refreshSystemInfo() }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        VStack(spacing: 12) {
            HStack {
                SectionTitle(title: "Disk Analyzer", icon: "chart.pie.fill", gradient: Theme.primaryGradient)
                Spacer()
                GradientButton("Analyze", icon: "magnifyingglass", gradient: Theme.primaryGradient, isLoading: vm.isScanning) {
                    navigationHistory = []
                    Task { await vm.analyzeDiskUsage() }
                }
            }

            // Breadcrumb path navigation
            breadcrumbBar
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 0) {
            // Back button
            Button {
                if let prev = navigationHistory.popLast() {
                    Task { await vm.navigateDiskUsage(to: prev) }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(navigationHistory.isEmpty ? .secondary.opacity(0.3) : Theme.brand)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(navigationHistory.isEmpty)

            Divider().frame(height: 16).padding(.horizontal, 6)

            // Home button
            Button {
                if vm.currentDiskPath != NSHomeDirectory() {
                    navigationHistory.append(vm.currentDiskPath)
                    Task { await vm.navigateDiskUsage(to: NSHomeDirectory()) }
                }
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16).padding(.horizontal, 6)

            // Path breadcrumbs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    let components = breadcrumbComponents
                    ForEach(components.indices, id: \.self) { idx in
                        if idx > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.quaternary)
                        }
                        Button {
                            let targetPath = components[0...idx].map(\.path).last ?? NSHomeDirectory()
                            if targetPath != vm.currentDiskPath {
                                navigationHistory.append(vm.currentDiskPath)
                                Task { await vm.navigateDiskUsage(to: targetPath) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if idx == 0 {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.brand)
                                }
                                Text(components[idx].name)
                                    .font(.system(size: 11, weight: idx == components.count - 1 ? .semibold : .regular))
                                    .foregroundStyle(idx == components.count - 1 ? .primary : .secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                idx == components.count - 1
                                    ? AnyShapeStyle(Theme.brand.opacity(0.08))
                                    : AnyShapeStyle(Color.clear)
                                , in: RoundedRectangle(cornerRadius: 4)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Disk info
            if vm.diskTotal > 0 {
                HStack(spacing: 6) {
                    diskUsageMiniBadge
                    Text("\(ByteCountFormatter.string(fromByteCount: vm.diskFree, countStyle: .file)) free")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
        )
    }

    private var diskUsageMiniBadge: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.primaryGradient)
                    .frame(width: vm.diskTotal > 0 ? geo.size.width * CGFloat(vm.diskUsed) / CGFloat(vm.diskTotal) : 0)
            }
        }
        .frame(width: 60, height: 8)
    }

    private struct BreadcrumbComponent {
        let name: String
        let path: String
    }

    private var breadcrumbComponents: [BreadcrumbComponent] {
        let home = NSHomeDirectory()
        let current = vm.currentDiskPath

        if current == home {
            return [BreadcrumbComponent(name: "~", path: home)]
        }

        guard current.hasPrefix(home) else {
            // Outside home — show full path
            let parts = current.split(separator: "/")
            var comps: [BreadcrumbComponent] = [BreadcrumbComponent(name: "/", path: "/")]
            var path = ""
            for part in parts {
                path += "/\(part)"
                comps.append(BreadcrumbComponent(name: String(part), path: path))
            }
            return comps
        }

        let relative = String(current.dropFirst(home.count))
        var comps: [BreadcrumbComponent] = [BreadcrumbComponent(name: "~", path: home)]
        let parts = relative.split(separator: "/")
        var path = home
        for part in parts {
            path += "/\(part)"
            comps.append(BreadcrumbComponent(name: String(part), path: path))
        }
        return comps
    }

    // MARK: - Empty View
    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 12)

                Image(systemName: "chart.pie")
                    .font(.system(size: 48))
                    .foregroundStyle(.quaternary)
                Text("Disk Space Analyzer")
                    .font(.system(size: 20, weight: .bold))
                Text("Visualize your disk space usage, find large files and folders, and free up space on your Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                // Volume picker cards
                if !vm.availableVolumes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select a volume to analyze")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 12)], spacing: 12) {
                            ForEach(vm.availableVolumes) { volume in
                                VolumeCard(volume: volume, isScanning: vm.isScanning) {
                                    vm.currentDiskPath = volume.mountPoint
                                    navigationHistory = []
                                    Task { await vm.analyzeDiskUsage() }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                } else {
                    GradientButton("Start Analysis", icon: "magnifyingglass", gradient: Theme.primaryGradient, isLoading: vm.isScanning) {
                        Task { await vm.analyzeDiskUsage() }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { vm.loadVolumes() }
    }

    // MARK: - Left Tree Panel
    private var leftTreePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Text("Name")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Size")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Total size row
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brand)
                Text((vm.currentDiskPath as NSString).lastPathComponent)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: totalSizeOfItems, countStyle: .file))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.brand.opacity(0.04))

            Divider()

            // File/folder list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.diskUsageItems) { item in
                        DiskTreeRow(
                            item: item,
                            totalParentSize: totalSizeOfItems,
                            isSelected: selectedItemId == item.id,
                            onSelect: { selectedItemId = item.id },
                            onNavigate: {
                                if item.isDirectory {
                                    selectedItemId = nil
                                    navigationHistory.append(vm.currentDiskPath)
                                    Task { await vm.navigateDiskUsage(to: item.path) }
                                }
                            }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)

            Divider()

            // Bottom summary
            HStack {
                Text("\(vm.diskUsageItems.count) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                let dirCount = vm.diskUsageItems.filter(\.isDirectory).count
                let fileCount = vm.diskUsageItems.count - dirCount
                Text("\(dirCount) folders, \(fileCount) files")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    // MARK: - Right Visualization Panel
    private var rightVisualizationPanel: some View {
        VStack(spacing: 0) {
            // Treemap
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Storage Map")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    treemapLegend
                }

                GeometryReader { geo in
                    let rects = TreemapLayout.layout(items: vm.diskUsageItems, in: CGRect(origin: .zero, size: geo.size))

                    ZStack(alignment: .topLeading) {
                        ForEach(rects) { tr in
                            TreemapCell(
                                tr: tr,
                                isHovered: hoveredTreemapId == tr.id || selectedItemId == tr.id,
                                onTap: {
                                    if tr.item.isDirectory {
                                        selectedItemId = nil
                                        navigationHistory.append(vm.currentDiskPath)
                                        Task { await vm.navigateDiskUsage(to: tr.item.path) }
                                    } else {
                                        selectedItemId = tr.id
                                    }
                                }
                            )
                            .onHover { isHovered in
                                hoveredTreemapId = isHovered ? tr.id : nil
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)

            Divider()

            // Selected item details / disk overview
            selectedItemInfo
        }
        .frame(maxWidth: .infinity)
    }

    private var treemapLegend: some View {
        HStack(spacing: 10) {
            legendDot(color: Color(red: 0.30, green: 0.58, blue: 1.0), label: "Folders")
            legendDot(color: Color(red: 0.9, green: 0.3, blue: 0.5), label: "Images")
            legendDot(color: Color(red: 0.8, green: 0.2, blue: 0.4), label: "Video")
            legendDot(color: Color(red: 0.9, green: 0.5, blue: 0.2), label: "Archives")
            legendDot(color: Color(red: 0.6, green: 0.6, blue: 0.65), label: "Other")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Selected Item Info Panel
    private var selectedItemInfo: some View {
        VStack(spacing: 0) {
            if let item = selectedItem {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(item.isDirectory ? Theme.brand.opacity(0.12) : Color.orange.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: item.isDirectory ? "folder.fill" : iconForFile(item.name))
                            .font(.system(size: 20))
                            .foregroundStyle(item.isDirectory ? Theme.brand : .orange)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(item.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.formattedSize)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.brand)
                        if totalSizeOfItems > 0 {
                            let pct = Double(item.size) / Double(totalSizeOfItems) * 100
                            Text(String(format: "%.1f%% of folder", pct))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Actions
                    VStack(spacing: 6) {
                        Button {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.glass)
                        .help("Reveal in Finder")

                        if item.isDirectory {
                            Button {
                                navigationHistory.append(vm.currentDiskPath)
                                Task { await vm.navigateDiskUsage(to: item.path) }
                            } label: {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.glass)
                            .help("Browse Directory")
                        }
                    }
                }
                .padding(16)
            } else {
                // Disk overview when nothing selected
                diskOverviewPanel
            }
        }
        .frame(height: 80)
        .background(.ultraThinMaterial)
    }

    private var diskOverviewPanel: some View {
        HStack(spacing: 24) {
            if vm.diskTotal > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Disk Overview")
                        .font(.system(size: 12, weight: .semibold))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.primaryGradient)
                                .frame(width: geo.size.width * CGFloat(vm.diskUsed) / CGFloat(vm.diskTotal))
                        }
                    }
                    .frame(height: 10)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: vm.diskFree, countStyle: .file))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.brand)
                    Text("available")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: vm.diskUsed, countStyle: .file))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("used")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Click Analyze to visualize disk space")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "app": return "app.fill"
        case "dmg", "iso": return "opticaldiscdrive.fill"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "m4a", "wav", "flac": return "music.note"
        case "pdf": return "doc.richtext"
        case "swift", "py", "js": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}

// MARK: - Disk Tree Row (left panel item)

private struct DiskTreeRow: View {
    let item: DiskUsageItem
    let totalParentSize: Int64
    let isSelected: Bool
    let onSelect: () -> Void
    let onNavigate: () -> Void

    @State private var isHovered = false

    private var sizePercentage: Double {
        guard totalParentSize > 0 else { return 0 }
        return Double(item.size) / Double(totalParentSize) * 100
    }

    private var barColor: Color {
        item.isDirectory
            ? TreemapLayout.colorFor(item: item, index: 0)
            : Color.orange
    }

    /// Real Finder icon for the file/folder
    private var finderIcon: NSImage {
        NSWorkspace.shared.icon(forFile: item.path)
    }

    var body: some View {
        Button {
            if item.isDirectory {
                onNavigate()
            } else {
                onSelect()
            }
        } label: {
            HStack(spacing: 8) {
                // Real macOS file/folder icon from Finder
                Image(nsImage: finderIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                // Name + percentage bar
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.name)
                            .font(.system(size: 11, weight: item.isDirectory ? .semibold : .regular))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }

                    // Proportional size bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor.opacity(0.5))
                                .frame(width: max(1, geo.size.width * CGFloat(sizePercentage) / 100))
                        }
                    }
                    .frame(height: 4)
                }

                // Size + percentage
                VStack(alignment: .trailing, spacing: 1) {
                    Text(item.formattedSize)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", sizePercentage))
                        .font(.system(size: 8, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 60, alignment: .trailing)

                // Navigate arrow for directories
                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.brand.opacity(isHovered ? 1 : 0.5))
                        .frame(width: 16, height: 16)
                } else {
                    Spacer().frame(width: 16)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.brand.opacity(0.1) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            if item.isDirectory {
                Button(action: onNavigate) {
                    Label("Browse Directory", systemImage: "arrow.right.circle")
                }
            }
        }
    }
}

// MARK: - Volume Picker Card

private struct VolumeCard: View {
    let volume: VolumeInfo
    let isScanning: Bool
    let onAnalyze: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onAnalyze) {
            HStack(spacing: 14) {
                // Volume icon from NSWorkspace
                Image(nsImage: volume.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text(volume.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    // Usage bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(usageColor)
                                .frame(width: max(2, geo.size.width * CGFloat(volume.usagePercent)))
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(formattedSize(volume.usedSize)) used")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formattedSize(volume.freeSize)) free")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.brand.opacity(isHovered ? 1 : 0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .shadow(color: .primary.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 8 : 3, y: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .disabled(isScanning)
    }

    private var usageColor: LinearGradient {
        if volume.usagePercent > 0.9 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if volume.usagePercent > 0.75 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        }
        return Theme.primaryGradient
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Legacy DiskRow (kept for backward compatibility)

struct DiskRow: View {
    let item: DiskUsageItem
    let maxSize: Int64
    let onNavigate: () -> Void
    @State private var isHovered = false

    private var barColor: LinearGradient {
        item.isDirectory ? Theme.primaryGradient : Theme.warningGradient
    }

    var body: some View {
        Button(action: onNavigate) {
            HStack(spacing: 10) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isDirectory ? Theme.primaryGradient : Theme.warningGradient)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.system(size: 12, weight: item.isDirectory ? .semibold : .regular))
                            .foregroundStyle(.primary).lineLimit(1)
                        Spacer()
                        Text(item.formattedSize)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if item.isDirectory {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor.opacity(0.5))
                                .frame(width: max(2, geo.size.width * CGFloat(item.size) / CGFloat(maxSize)))
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .shadow(color: .primary.opacity(isHovered ? 0.06 : 0.03), radius: isHovered ? 5 : 2, y: 1)
        )
        .onHover { isHovered = $0 }
    }
}
