//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct JunkCleanerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var selectedCategory: JunkCategory? = nil
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            if vm.isScanning {
                scanningView
            } else if vm.junkItems.isEmpty {
                emptyView
            } else {
                splitView
            }

            if vm.isCleaning {
                CleaningProgressOverlay(
                    progress: vm.cleaningProgress,
                    currentFile: vm.cleaningCurrentFile,
                    freedSoFar: vm.cleaningFreedSoFar
                )
            }
        }
        .onAppear {
            if !vm.junkItems.isEmpty && selectedCategory == nil {
                selectedCategory = JunkCategory.allCases.first(where: { vm.junkByCategory[$0]?.isEmpty == false })
            }
        }
    }
    
    // MARK: - Scanning View
    private var scanningView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 20)
            Text("Scanning Flash Clean...")
                .font(.system(size: 18, weight: .bold))
            Text("\(vm.scanningFilesFound) files found")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if !vm.scanningCurrentPath.isEmpty {
                Text(vm.scanningCurrentPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.primaryGradient)
                .padding(.bottom, 10)
            
            Text("Flash Clean")
                .font(.system(size: 28, weight: .bold))
            
            Text("Scan your Mac to find and safely remove junk files, caches, logs, and temporary data.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button {
                Task { await vm.scanJunk() }
            } label: {
                Text("Scan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 160, height: 44)
                    .background(Theme.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Split View
    private var splitView: some View {
        VStack(spacing: 0) {
            // Top Toolbar matching Start Over
            HStack {
                Button {
                    vm.junkItems = []
                    vm.totalJunkSize = 0
                    vm.selectedJunkCount = 0
                    vm.selectedJunkSize = 0
                    selectedCategory = nil
                    vm.isScanning = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Start Over")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Flash Clean")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button {
                    Task { await vm.scanJunk() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            HStack(spacing: 0) {
                leftPanel
                    .frame(width: 280)
                Divider()
                rightPanel
            }
            Divider()
            bottomActionBar
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Left Panel
    private var leftPanel: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button {
                    let isAllSelected = vm.selectedJunkCount == vm.junkItems.count
                    vm.toggleAllJunk(selected: !isAllSelected)
                } label: {
                    Text(vm.selectedJunkCount == vm.junkItems.count ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Sort by Size ▾")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(JunkCategory.allCases) { cat in
                        if let items = vm.junkByCategory[cat], !items.isEmpty {
                            categoryRow(cat: cat, items: items)
                        } else if cat == .trashCan && vm.trashAccessDenied {
                            categoryRow(cat: cat, items: [])
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func categoryRow(cat: JunkCategory, items: [JunkItem]) -> some View {
        let isSelected = selectedCategory == cat
        let isAllChecked = items.count > 0 && items.allSatisfy { $0.isSelected }
        let isPartiallyChecked = items.count > 0 && items.contains { $0.isSelected } && !isAllChecked
        let totalSize = items.reduce(Int64(0)) { $0 + $1.size }
        let catColor = Color(red: cat.color.r, green: cat.color.g, blue: cat.color.b)

        return Button {
            selectedCategory = cat
        } label: {
            HStack(spacing: 12) {
                // Custom Checkbox
                Button {
                    if cat == .trashCan && vm.trashAccessDenied { return }
                    vm.toggleJunkCategory(cat, selected: !isAllChecked)
                } label: {
                    if cat == .trashCan && vm.trashAccessDenied {
                        Image(systemName: "minus.square")
                            .foregroundStyle(.secondary.opacity(0.3))
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: isAllChecked ? "checkmark.square.fill" : (isPartiallyChecked ? "minus.square.fill" : "square"))
                            .foregroundStyle(isAllChecked || isPartiallyChecked ? Theme.brand : .secondary)
                            .font(.system(size: 16))
                    }
                }
                .buttonStyle(.plain)

                // Colored Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(catColor)
                        .frame(width: 28, height: 28)
                    Image(systemName: cat.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }

                Text(cat.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()

                Text(cat == .trashCan && vm.trashAccessDenied ? "Grant Access" : ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(cat == .trashCan && vm.trashAccessDenied ? Theme.brand : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right Panel
    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cat = selectedCategory {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(cat.rawValue)
                        .font(.system(size: 24, weight: .bold))
                    Text(descriptionForCategory(cat))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Divider()
                
                HStack {
                    Spacer()
                    Text("Sort by Size ▾")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                
                let items = vm.junkByCategory[cat] ?? []
                if cat == .browserCache {
                    browserCacheList(items: items)
                } else if cat == .trashCan && vm.trashAccessDenied {
                    trashAccessDeniedView
                } else {
                    standardFileList(items: items)
                }
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Browser Cache List
    private func browserCacheList(items: [JunkItem]) -> some View {
        let grouped = Dictionary(grouping: items) { $0.browserApp ?? .safari }
        let sortedBrowsers = grouped.keys.sorted {
            (grouped[$0]?.reduce(0) { $0 + $1.size } ?? 0) > (grouped[$1]?.reduce(0) { $0 + $1.size } ?? 0)
        }
        
        return ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(sortedBrowsers) { browser in
                    if let bItems = grouped[browser], !bItems.isEmpty {
                        let totalSize = bItems.reduce(0) { $0 + $1.size }
                        let isAllChecked = bItems.allSatisfy { $0.isSelected }
                        
                        HStack(spacing: 12) {
                            Button {
                                let newState = !isAllChecked
                                for item in bItems {
                                    if let idx = vm.junkItems.firstIndex(where: { $0.id == item.id }) {
                                        vm.junkItems[idx].isSelected = newState
                                    }
                                }
                                vm.junkByCategory[.browserCache] = vm.junkItems.filter { $0.category == .browserCache }
                                vm.updateJunkSelection()
                            } label: {
                                Image(systemName: isAllChecked ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isAllChecked ? Theme.brand : .secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            
                            if FileManager.default.fileExists(atPath: browser.appPath) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: browser.appPath))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.blue)
                            }
                            
                            Text(browser.rawValue + ".app")
                                .font(.system(size: 13, weight: .medium))
                            
                            Spacer()
                            
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Standard File List
    private func standardFileList(items: [JunkItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items.prefix(300)) { item in
                    HStack(spacing: 12) {
                        Button {
                            vm.toggleJunkItem(item)
                        } label: {
                            Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isSelected ? Theme.brand : .secondary)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                            .resizable()
                            .frame(width: 20, height: 20)
                        
                        Text(item.fileName)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Text(item.formattedSize)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Trash Access Denied View
    private var trashAccessDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Full Disk Access Required")
                .font(.system(size: 18, weight: .bold))
            Text("To calculate and empty the Trash, Cleankeun requires Full Disk Access. Grant it in System Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open System Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func descriptionForCategory(_ cat: JunkCategory) -> String {
        switch cat {
        case .purgeableSpace: return "Storage space that macOS can automatically free up when needed."
        case .systemCache: return "System-level cache and temporary files generated during normal operation."
        case .userCache: return "Cache files created by installed applications. Safe to delete — apps will rebuild them."
        case .xcode: return "Xcode build artifacts, derived data, simulator caches, and archives."
        case .browserCache: return "A browser's cache is its appliance or instrument through which it saves data, such as images, browsing histories and cached webpages."
        case .systemLogs: return "System-level log files from macOS and system services."
        case .crashReports: return "Crash reports and diagnostic data from application crashes."
        case .unusedDMGs: return "Disk image files in Downloads that have already been mounted/installed."
        case .userLogs: return "Application log files that accumulate in your user Library."
        case .trashCan: return "Files in the macOS Trash that haven't been permanently deleted yet."
        case .downloads: return "Files in your Downloads folder that may no longer be needed."
        case .screenCaptures: return "Screenshot files saved to your Desktop by macOS."
        case .mailAttachments: return "Cached email attachments and downloaded mail data from Mail.app."
        case .iOSBackups: return "Old backups of iOS devices stored on your Mac."
        }
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack {
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(ByteCountFormatter.string(fromByteCount: vm.selectedJunkSize, countStyle: .file))")
                    .font(.system(size: 24, weight: .regular))
                Text("Selected")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 16)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(ByteCountFormatter.string(fromByteCount: vm.totalJunkSize, countStyle: .file))")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Total")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 24)
            
            Button {
                showConfirm = true
            } label: {
                Text("Remove")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 36)
                    .background(vm.selectedJunkCount > 0 ? Theme.brand : Color.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(vm.selectedJunkCount == 0)
            .alert("Confirm Permanent Deletion", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { Task { await vm.cleanJunk() } }
            } message: {
                Text("Permanently delete \(vm.selectedJunkCount) files? This cannot be undone.")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Indeterminate Progress Bar
struct IndeterminateProgressBar: View {
    @State private var offset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))

                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.primaryGradient)
                    .frame(width: geo.size.width * 0.3)
                    .offset(x: offset * geo.size.width)
            }
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                offset = 0.7
            }
        }
    }
}

// MARK: - Cleaning Progress Overlay
struct CleaningProgressOverlay: View {
    let progress: Double
    let currentFile: String
    let freedSoFar: Int64

    @State private var animatedProgress: Double = 0
    @State private var sparkleRotation: Double = 0

    var body: some View {
        ZStack {
            Color.primary.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Theme.brand.opacity(0.15)).frame(width: 80, height: 80)
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .rotationEffect(.degrees(sparkleRotation))
                }
                VStack(spacing: 8) {
                    Text("Deleting Files").font(.system(size: 18, weight: .bold))
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                }
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.1))
                            RoundedRectangle(cornerRadius: 6).fill(Theme.primaryGradient).frame(width: geo.size.width * animatedProgress)
                        }
                    }
                    .frame(height: 12).frame(maxWidth: 300)
                    if freedSoFar > 0 {
                        Text("Freed \(ByteCountFormatter.string(fromByteCount: freedSoFar, countStyle: .file))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.brand)
                    }
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThickMaterial).glassEffect(.regular, in: .rect(cornerRadius: 20)).shadow(radius: 30, y: 10))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { sparkleRotation = 360 }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) { animatedProgress = newValue }
        }
    }
}

// MARK: - Re-adding Missing Shared Components for other views

struct BottomBar<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .glassEffect(.regular, in: .rect)
    }
}

