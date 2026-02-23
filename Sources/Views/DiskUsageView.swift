//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI
import AppKit

// MARK: - DiskUsageView

struct DiskUsageView: View {
    @Environment(AppViewModel.self) var vm
    @State private var navigationHistory: [String] = []
    @State private var forwardHistory: [String] = []
    @State private var selectedPaths: Set<String> = []
    @State private var selectedVolume: VolumeInfo? = nil
    @State private var showConfirm = false

    private var totalSizeOfItems: Int64 {
        vm.diskUsageItems.reduce(0) { $0 + $1.size }
    }
    
    private var totalSelectedBytes: Int64 {
        vm.diskUsageItems.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.currentDiskPath.isEmpty {
                emptyStartScreen
            } else {
                topToolbar
                Divider()
                mainListPanel
                Divider()
                bottomBar
            }
        }
        .onAppear { vm.loadVolumes() }
    }

    // MARK: - Start Screen
    private var emptyStartScreen: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Disk Space Analyzer")
                    .font(.system(size: 28, weight: .bold))
                Text("Scan your disk to find and remove large files and folders.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            HStack(spacing: 60) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Use this tool to:")
                        .font(.system(size: 16, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("Analyze your storage usage deeply")
                        bulletPoint("Find out which folders use the most space")
                        bulletPoint("Quickly remove old unused files")
                        bulletPoint("Free up gigabytes of space")
                    }
                }
                
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.primaryGradient)
                    .frame(width: 140, height: 140)
                    .background(Theme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(.top, 20)
            
            VStack(spacing: 20) {
                if !vm.availableVolumes.isEmpty {
                    Menu {
                        ForEach(vm.availableVolumes) { vol in
                            Button {
                                selectedVolume = vol
                            } label: {
                                Label(vol.name, image: "internaldrive")
                            }
                        }
                    } label: {
                        HStack {
                            if let icon = selectedVolume?.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(selectedVolume?.name ?? vm.availableVolumes.first?.name ?? "Select Volume")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(width: 200)
                    }
                    .menuStyle(.borderedButton)
                    .controlSize(.large)
                }
                
                Button {
                    let path = selectedVolume?.mountPoint ?? vm.availableVolumes.first?.mountPoint ?? NSHomeDirectory()
                    vm.currentDiskPath = path
                    navigationHistory = []
                    forwardHistory = []
                    selectedPaths.removeAll()
                    Task { await vm.analyzeDiskUsage() }
                } label: {
                    Text("Scan Disk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 44)
                        .background(Theme.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .disabled(vm.isScanningDiskUsage)
                
                if vm.isScanningDiskUsage {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text("Allow Cleankeun to scan storage by granting Full Disk Access.")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text).font(.system(size: 14)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 16) {
            Button {
                vm.diskUsageItems = []
                vm.currentDiskPath = ""
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .accessibilityLabel("Go Up One Directory")
                    Text("Start Over")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Disk Space Analyzer")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Breadcrumbs
    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                let parts = vm.currentDiskPath == "/" ? ["/"] : vm.currentDiskPath.components(separatedBy: "/").filter { !$0.isEmpty }
                
                Button {
                    Task { await vm.navigateDiskUsage(to: "/") }
                } label: {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(Theme.brand)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                
                if parts != ["/"] {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    ForEach(0..<parts.count, id: \.self) { i in
                        let isLast = i == parts.count - 1
                        let partialPath = "/" + parts[0...i].joined(separator: "/")
                        
                        Button {
                            if !isLast {
                                Task { await vm.navigateDiskUsage(to: partialPath) }
                            }
                        } label: {
                            Text(parts[i])
                                .font(.system(size: 13, weight: isLast ? .bold : .medium))
                                .foregroundStyle(isLast ? Color.primary : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        if !isLast {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Main List Panel
    private var mainListPanel: some View {
        VStack(spacing: 0) {
            breadcrumbView
            Divider()
            
            if vm.isScanningDiskUsage {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Scanning folder...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if !vm.diskUsageItems.isEmpty {
                        TreemapContainer(items: vm.diskUsageItems, totalSize: totalSizeOfItems) { item in
                            if item.isDirectory {
                                navigationHistory.append(vm.currentDiskPath)
                                forwardHistory.removeAll()
                                Task { await vm.navigateDiskUsage(to: item.path, withChildren: item.children) }
                            } else {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        
                        Divider()
                    }
                    
                    List {
                        let totalSize = totalSizeOfItems
                        ForEach(vm.diskUsageItems) { item in
                        DiskTreeRow(
                            item: item,
                            parentTotalSize: totalSize,
                            isSelected: selectedPaths.contains(item.path),
                            onToggleSelect: {
                                if selectedPaths.contains(item.path) {
                                    selectedPaths.remove(item.path)
                                } else {
                                    selectedPaths.insert(item.path)
                                }
                            },
                            onNavigate: {
                                if item.isDirectory {
                                    navigationHistory.append(vm.currentDiskPath)
                                    forwardHistory.removeAll()
                                    Task { await vm.navigateDiskUsage(to: item.path, withChildren: item.children) }
                                } else {
                                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(totalSelectedBytes > 0 ? ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file) : "0 Byte")")
                    .font(.system(size: 24, weight: .regular))
                Text("Selected")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 20)
            
            Button {
                showConfirm = true
            } label: {
                Text("Remove")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 36)
                    .background(totalSelectedBytes > 0 ? Theme.brand : Color.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(totalSelectedBytes == 0)
            .confirmationDialog(
                "Delete Selected Items?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Permanently", role: .destructive) {
                    let pathsToDelete = selectedPaths
                    Task {
                        await vm.deleteDiskItems(paths: pathsToDelete)
                        selectedPaths.removeAll()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action will permanently delete \(selectedPaths.count) items (\(ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file))). This cannot be undone.")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Treemap Container

struct TreemapContainer: View {
    let items: [DiskUsageItem]
    let totalSize: Int64
    let onNavigate: (DiskUsageItem) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                let rects = calculateSquarifiedTreemap(items: items, rect: CGRect(origin: .zero, size: geo.size), totalSize: totalSize)
                ForEach(rects) { node in
                    TreemapNodeView(node: node)
                        .onTapGesture {
                            onNavigate(node.item)
                        }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // A simplified squarified layout
    private func calculateSquarifiedTreemap(items: [DiskUsageItem], rect: CGRect, totalSize: Int64) -> [TreemapNode] {
        var result: [TreemapNode] = []
        let sorted = items.sorted { $0.size > $1.size }
        guard !sorted.isEmpty, totalSize > 0, rect.width > 0, rect.height > 0 else { return [] }
        
        let colors: [Color] = [
            Color(red: 0.9, green: 0.3, blue: 0.3),
            Color(red: 0.9, green: 0.6, blue: 0.2),
            Color(red: 0.3, green: 0.7, blue: 0.9),
            Color(red: 0.3, green: 0.8, blue: 0.5),
            Color(red: 0.6, green: 0.4, blue: 0.9),
            Color(red: 0.9, green: 0.4, blue: 0.7)
        ]
        
        var currentRect = rect
        var remainingSize = totalSize
        
        // Very basic slice and dice layout for simplicity, grouping very small files
        for (i, item) in sorted.enumerated() {
            if item.size <= 0 { continue }
            let ratio = CGFloat(item.size) / CGFloat(remainingSize)
            var slice: CGRect
            var nextRect: CGRect
            
            if currentRect.width > currentRect.height {
                // Split horizontally
                let w = currentRect.width * ratio
                slice = CGRect(x: currentRect.minX, y: currentRect.minY, width: w, height: currentRect.height)
                nextRect = CGRect(x: currentRect.minX + w, y: currentRect.minY, width: currentRect.width - w, height: currentRect.height)
            } else {
                // Split vertically
                let h = currentRect.height * ratio
                slice = CGRect(x: currentRect.minX, y: currentRect.minY, width: currentRect.width, height: h)
                nextRect = CGRect(x: currentRect.minX, y: currentRect.minY + h, width: currentRect.width, height: currentRect.height - h)
            }
            
            let color = colors[i % colors.count]
            result.append(TreemapNode(item: item, rect: slice, color: color))
            
            currentRect = nextRect
            remainingSize -= item.size
        }
        
        return result
    }
}

struct TreemapNode: Identifiable {
    let id = UUID()
    let item: DiskUsageItem
    let rect: CGRect
    let color: Color
}

struct TreemapNodeView: View {
    let node: TreemapNode
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(node.color.opacity(isHovered ? 0.9 : 0.7))
                .border(Color(NSColor.windowBackgroundColor), width: 1)
            
            if node.rect.width > 40 && node.rect.height > 30 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.item.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(radius: 1)
                    Text(node.item.formattedSize)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .shadow(radius: 1)
                }
                .padding(4)
            }
        }
        .frame(width: node.rect.width, height: node.rect.height)
        .position(x: node.rect.minX + node.rect.width / 2, y: node.rect.minY + node.rect.height / 2)
        .onHover { isHovered = $0 }
        .help("\(node.item.name)\n\(node.item.formattedSize)")
    }
}

private struct DiskTreeRow: View {
    let item: DiskUsageItem
    let parentTotalSize: Int64
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onNavigate: () -> Void

    @State private var isHovered = false

    private var finderIcon: NSImage {
        NSWorkspace.shared.icon(forFile: item.path)
    }
    
    private var sizeRatio: Double {
        guard parentTotalSize > 0 else { return 0 }
        return Double(item.size) / Double(parentTotalSize)
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Theme.brand : .secondary)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                onNavigate()
            }) {
                HStack(spacing: 12) {
                    Image(nsImage: finderIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(item.formattedSize)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.brand)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.brand.opacity(0.8))
                                    .frame(width: geo.size.width * CGFloat(sizeRatio), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    if item.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .padding(.leading, 8)
                    } else {
                        Spacer().frame(width: 20)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(isSelected ? Theme.brand.opacity(0.05) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
    }
}
