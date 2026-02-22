//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct JunkCleanerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var showConfirm = false
    @State private var selectedCategory: JunkCategory? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if vm.isScanning {
                    // Scanning view
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                SectionTitle(
                                    title: "Flash Clean", icon: "bolt.circle.fill",
                                    gradient: Theme.primaryGradient)
                                Spacer()
                            }

                            ScanningAnimationView(
                                currentPath: vm.scanningCurrentPath,
                                filesFound: vm.scanningFilesFound
                            )

                            // Live category counters during scan
                            if !vm.junkByCategory.isEmpty {
                                scanCategoryProgress
                            }
                        }
                        .padding(28)
                    }
                    .scrollIndicators(.hidden)
                } else if vm.junkItems.isEmpty {
                    // Empty state
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                SectionTitle(
                                    title: "Flash Clean", icon: "bolt.circle.fill",
                                    gradient: Theme.primaryGradient)
                                Spacer()
                                GradientButton(
                                    "Scan", icon: "magnifyingglass", gradient: Theme.primaryGradient
                                ) {
                                    Task { await vm.scanJunk() }
                                }
                            }

                            EmptyState(
                                icon: "sparkles", title: "System Looks Clean",
                                subtitle:
                                    "Click Scan to find junk files, caches, logs, and temporary files on your Mac",
                                gradient: Theme.primaryGradient)
                        }
                        .padding(28)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    // BuhoCleaner-style split panel results
                    resultView
                }
            }

            // Cleaning progress overlay
            if vm.isCleaning {
                CleaningProgressOverlay(
                    progress: vm.cleaningProgress,
                    currentFile: vm.cleaningCurrentFile,
                    freedSoFar: vm.cleaningFreedSoFar
                )
            }
        }
    }

    // MARK: - Live Scan Category Progress
    private var scanCategoryProgress: some View {
        VStack(spacing: 12) {
            ForEach(JunkCategory.allCases) { cat in
                if let items = vm.junkByCategory[cat], !items.isEmpty {
                    let catColor = Color(red: cat.color.r, green: cat.color.g, blue: cat.color.b)
                    let catSize = items.reduce(Int64(0)) { $0 + $1.size }
                    HStack(spacing: 10) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(catColor)
                            .frame(width: 20)
                        Text(cat.rawValue)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(items.count) files")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: catSize, countStyle: .file))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(catColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        )
    }

    // MARK: - BuhoCleaner-style Result View (Split Panel)
    private var resultView: some View {
        VStack(spacing: 0) {
            // Top header
            resultHeader

            Divider()

            // Split panel: categories on left, files on right
            HStack(spacing: 0) {
                leftCategoryPanel
                Divider()
                rightFilePanel
            }

            // Bottom action bar
            bottomActionBar
        }
    }

    private var resultHeader: some View {
        HStack {
            SectionTitle(
                title: "Flash Clean", icon: "bolt.circle.fill",
                gradient: Theme.primaryGradient)
            Spacer()

            // Summary info
            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: vm.totalJunkSize, countStyle: .file))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Text("\(vm.junkItems.count) files across \(vm.junkByCategory.count) categories")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            GradientButton(
                "Re-scan", icon: "arrow.clockwise", gradient: Theme.primaryGradient
            ) {
                selectedCategory = nil
                Task { await vm.scanJunk() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Left Category Panel
    private var leftCategoryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Select all/none controls
            HStack {
                Button("Select All") { vm.toggleAllJunk(selected: true) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                Text("|").foregroundStyle(.separator).font(.system(size: 10))
                Button("Deselect All") { vm.toggleAllJunk(selected: false) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Category list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(JunkCategory.allCases) { cat in
                        let hasItems = vm.junkByCategory[cat] != nil && !vm.junkByCategory[cat]!.isEmpty
                        let showTrash = cat == .trashCan && vm.trashAccessDenied
                        if hasItems || showTrash {
                            CategoryListRow(
                                category: cat,
                                items: vm.junkByCategory[cat] ?? [],
                                isSelected: selectedCategory == cat,
                                trashAccessDenied: cat == .trashCan && vm.trashAccessDenied,
                                onSelect: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategory = cat
                                    }
                                },
                                onToggle: { selected in
                                    vm.toggleJunkCategory(cat, selected: selected)
                                }
                            )
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            Divider()

            // Total selected summary
            HStack {
                Circle()
                    .fill(Theme.brand)
                    .frame(width: 8, height: 8)
                Text("Selected:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: vm.selectedJunkSize, countStyle: .file))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    // MARK: - Right File Panel
    private var rightFilePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cat = selectedCategory {
                let items = vm.junkByCategory[cat] ?? []

                // Special case: Trash Can with access denied and no items
                if cat == .trashCan && vm.trashAccessDenied && items.isEmpty {
                    trashAccessDeniedPanel
                } else if !items.isEmpty {
                    // Category info header
                    categoryInfoHeader(cat: cat, items: items)

                    Divider()

                    // Category-specific detail views
                    if cat == .purgeableSpace {
                        purgeableSpacePanel(items: items)
                    } else if cat == .browserCache {
                        browserCachePanel(items: items)
                    } else if cat == .trashCan && vm.trashAccessDenied {
                        // Has some items but also access denied
                        trashAccessDeniedPanel
                    } else if cat == .downloads || cat == .screenCaptures {
                        finderIconFilePanel(items: items, cat: cat)
                    } else {
                        defaultFilePanel(items: items, cat: cat)
                    }
                } else {
                    // Category selected but no items
                    overviewPanel
                }
            } else {
                // No category selected — show overview
                overviewPanel
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Purgeable Space Panel (BuhoCleaner-style)
    private func purgeableSpacePanel(items: [JunkItem]) -> some View {
        let totalSize = items.reduce(Int64(0)) { $0 + $1.size }
        let catColor = Color(red: JunkCategory.purgeableSpace.color.r, green: JunkCategory.purgeableSpace.color.g, blue: JunkCategory.purgeableSpace.color.b)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Explanation card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(catColor)
                        Text("About Purgeable Space")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text("macOS keeps purgeable data (expired caches, Time Machine local snapshots, and other temporary files) that can be reclaimed when disk space is needed.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        instructionRow(number: "1", text: "You can reclaim up to \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)) of purgeable space.")
                        instructionRow(number: "2", text: "This triggers macOS to purge cached data and local snapshots. Requires administrator password.")
                        instructionRow(number: "3", text: "The process may take a while to fully take effect. Disk space will gradually become available.")
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                )

                // The single purgeable item row
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(catColor.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(catColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Purgeable Space")
                            .font(.system(size: 13, weight: .semibold))
                        Text("macOS-managed cached data and local snapshots")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(catColor)

                    Image(systemName: items.first?.isSelected == true ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(items.first?.isSelected == true ? catColor : .secondary.opacity(0.4))
                        .font(.system(size: 18))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                )
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.brand.opacity(0.12))
                    .frame(width: 22, height: 22)
                Text(number)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
            }

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Trash Access Denied Panel
    private var trashAccessDeniedPanel: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                Text("Trash Access Required")
                    .font(.system(size: 18, weight: .bold))
                Text("Cleankeun needs Full Disk Access to read your Trash folder. Grant access in System Settings, or use Finder to empty Trash.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            HStack(spacing: 12) {
                Button {
                    // Open System Settings > Privacy > Full Disk Access
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                        Text("Open System Settings")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    // Empty trash via Finder AppleScript
                    Task { await vm.cleanJunk() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11))
                        Text("Empty via Finder")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Finder Icon File Panel (Downloads / Screen Captures)
    private func finderIconFilePanel(items: [JunkItem], cat: JunkCategory) -> some View {
        let catColor = Color(red: cat.color.r, green: cat.color.g, blue: cat.color.b)

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items.prefix(200)) { item in
                    Button {
                        vm.toggleJunkItem(item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isSelected ? catColor : .secondary.opacity(0.4))
                                .font(.system(size: 14))

                            // Real Finder icon
                            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            Text(item.fileName)
                                .font(.system(size: 11))
                                .lineLimit(1).truncationMode(.middle)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(item.formattedSize)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(item.isSelected ? catColor.opacity(0.04) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        }
                        Button(item.isSelected ? "Deselect" : "Select") {
                            vm.toggleJunkItem(item)
                        }
                    }
                }
                if items.count > 200 {
                    Text("+ \(items.count - 200) more files")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Default File Panel
    private func defaultFilePanel(items: [JunkItem], cat: JunkCategory) -> some View {
        let catColor = Color(red: cat.color.r, green: cat.color.g, blue: cat.color.b)

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items.prefix(200)) { item in
                    JunkFileRow(item: item, catColor: catColor, onToggleItem: { vm.toggleJunkItem($0) })
                }
                if items.count > 200 {
                    Text("+ \(items.count - 200) more files")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Per-Browser Cache Panel
    private func browserCachePanel(items: [JunkItem]) -> some View {
        let grouped = Dictionary(grouping: items) { $0.browserApp ?? .safari }
        let sortedBrowsers = grouped.keys.sorted { a, b in
            let sizeA = grouped[a]?.reduce(0) { $0 + $1.size } ?? 0
            let sizeB = grouped[b]?.reduce(0) { $0 + $1.size } ?? 0
            return sizeA > sizeB
        }

        return ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(sortedBrowsers) { browser in
                    if let browserItems = grouped[browser], !browserItems.isEmpty {
                        BrowserCacheGroupRow(
                            browser: browser,
                            items: browserItems,
                            onToggleItem: { vm.toggleJunkItem($0) },
                            onToggleBrowser: { selected in
                                for item in browserItems {
                                    if let idx = vm.junkItems.firstIndex(where: { $0.id == item.id }) {
                                        vm.junkItems[idx].isSelected = selected
                                    }
                                }
                                vm.toggleJunkCategory(.browserCache, selected: vm.junkItems.filter { $0.category == .browserCache && $0.isSelected }.count == vm.junkItems.filter { $0.category == .browserCache }.count)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func categoryInfoHeader(cat: JunkCategory, items: [JunkItem]) -> some View {
        let catColor = Color(red: cat.color.r, green: cat.color.g, blue: cat.color.b)
        let totalSize = items.reduce(Int64(0)) { $0 + $1.size }
        let selectedCount = items.filter(\.isSelected).count
        let fileLabel = cat.isVirtual ? "1 item" : "\(items.count) files"
        let selectedLabel = cat.isVirtual ? (selectedCount > 0 ? "selected" : "not selected") : "\(selectedCount) selected"

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(catColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: cat.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(catColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(cat.rawValue)
                    .font(.system(size: 16, weight: .bold))
                Text(descriptionForCategory(cat))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(catColor)
                Text("\(fileLabel) • \(selectedLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // Toggle all in category (not for virtual categories)
            if !cat.isVirtual {
                Button {
                    let allSelected = selectedCount == items.count
                    vm.toggleJunkCategory(cat, selected: !allSelected)
                } label: {
                    Image(systemName: selectedCount == items.count ? "checkmark.square.fill" :
                          (selectedCount > 0 ? "minus.square.fill" : "square"))
                        .foregroundStyle(selectedCount > 0 ? catColor : .secondary.opacity(0.4))
                        .font(.system(size: 20))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private func descriptionForCategory(_ cat: JunkCategory) -> String {
        switch cat {
        case .purgeableSpace: return "Purgeable Space includes cached files, temporary files, and other items that your Mac has determined can be safely removed."
        case .systemCache: return "System-level cache and temporary files generated during normal operation."
        case .userCache: return "Cache files created by installed applications. Safe to delete — apps will rebuild them."
        case .xcode: return "Xcode build artifacts, derived data, simulator caches, and archives."
        case .browserCache: return "Web browser cache files from Safari, Chrome, Firefox, and other browsers."
        case .systemLogs: return "System-level log files from macOS and system services."
        case .crashReports: return "Crash reports and diagnostic data from application crashes."
        case .unusedDMGs: return "Disk image files in Downloads that have already been mounted/installed."
        case .userLogs: return "Application log files that accumulate in your user Library."
        case .trashCan: return "Files in the macOS Trash that haven't been permanently deleted yet."
        case .downloads: return "Files in your Downloads folder that may no longer be needed."
        case .screenCaptures: return "Screenshot files saved to your Desktop by macOS."
        case .mailAttachments: return "Cached email attachments and downloaded mail data from Mail.app."
        case .iOSBackups: return "Old iOS device backups stored by Finder or iTunes."
        }
    }

    // MARK: - Overview Panel (when no category selected)
    private var overviewPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary card
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.brand)
                                Text("Scan Complete")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text("Select a category on the left to view individual files")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(ByteCountFormatter.string(fromByteCount: vm.totalJunkSize, countStyle: .file))
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.brand)
                            Text("total junk found")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                )

                // Category breakdown chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Breakdown by Category")
                        .font(.system(size: 13, weight: .semibold))

                    ForEach(JunkCategory.allCases) { cat in
                        if let items = vm.junkByCategory[cat], !items.isEmpty {
                            let catColor = Color(red: cat.color.r, green: cat.color.g, blue: cat.color.b)
                            let catSize = items.reduce(Int64(0)) { $0 + $1.size }
                            let pct = vm.totalJunkSize > 0 ? Double(catSize) / Double(vm.totalJunkSize) : 0

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCategory = cat
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(catColor.opacity(0.12))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 12))
                                            .foregroundStyle(catColor)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(cat.rawValue)
                                                .font(.system(size: 12, weight: .semibold))
                                            Spacer()
                        Text(cat.isVirtual ? "1 item" : "\(items.count) files")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                            Text(ByteCountFormatter.string(fromByteCount: catSize, countStyle: .file))
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(catColor)
                                        }

                                        // Proportional bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.primary.opacity(0.04))
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(catColor.opacity(0.5))
                                                    .frame(width: max(2, geo.size.width * CGFloat(pct)))
                                            }
                                        }
                                        .frame(height: 5)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                )
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        BottomBar {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.selectedJunkCount) items selected")
                        .font(.system(size: 13, weight: .medium))
                    Text(
                        ByteCountFormatter.string(
                            fromByteCount: vm.selectedJunkSize, countStyle: .file)
                    )
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                GradientButton(
                    "Delete Permanently", icon: "trash",
                    gradient: vm.selectedJunkCount > 0
                        ? Theme.dangerGradient
                        : LinearGradient(
                            colors: [.gray], startPoint: .leading, endPoint: .trailing)
                ) {
                    showConfirm = true
                }
                .disabled(vm.selectedJunkCount == 0)
            }
        }
        .alert("Confirm Permanent Deletion", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) { Task { await vm.cleanJunk() } }
        } message: {
            Text(
                "Permanently delete \(vm.selectedJunkCount) files (\(ByteCountFormatter.string(fromByteCount: vm.selectedJunkSize, countStyle: .file)))? This cannot be undone."
            )
        }
    }
}

// MARK: - Category List Row (left panel)

private struct CategoryListRow: View {
    let category: JunkCategory
    let items: [JunkItem]
    let isSelected: Bool
    let trashAccessDenied: Bool
    let onSelect: () -> Void
    let onToggle: (Bool) -> Void

    @State private var isHovered = false

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    private var selectedCount: Int { items.filter(\.isSelected).count }
    private var catColor: Color {
        Color(red: category.color.r, green: category.color.g, blue: category.color.b)
    }

    /// Whether this row should show "Grant Access" instead of normal controls
    private var showGrantAccess: Bool {
        category == .trashCan && trashAccessDenied
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                if showGrantAccess {
                    // No checkbox for trash when access denied
                    Color.clear.frame(width: 22, height: 22)
                } else {
                    // Checkbox
                    Button {
                        let allSelected = selectedCount == items.count
                        onToggle(!allSelected)
                    } label: {
                        Image(systemName: selectedCount == items.count ? "checkmark.square.fill" :
                              (selectedCount > 0 ? "minus.square.fill" : "square"))
                            .foregroundStyle(selectedCount > 0 ? catColor : .secondary.opacity(0.4))
                            .font(.system(size: 16))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(catColor.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: category.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(catColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if showGrantAccess {
                        Text("Grant Access")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                    } else {
                        let label = category.isVirtual ? "1 item" : "\(items.count) files"
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !showGrantAccess {
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(catColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.brand.opacity(0.1) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Scanning Animation View (BuhoCleaner-style)
struct ScanningAnimationView: View {
    let currentPath: String
    let filesFound: Int

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(Theme.brand.opacity(0.15), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(Theme.brand.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Theme.brand)
                    .rotationEffect(.degrees(rotation))
            }

            VStack(spacing: 8) {
                Text("Scanning Your System")
                    .font(.system(size: 18, weight: .bold))

                Text("\(filesFound) files found")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brand)
            }

            // Animated progress bar (indeterminate)
            IndeterminateProgressBar()
                .frame(maxWidth: 320)

            // Currently scanning path
            if !currentPath.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(currentPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
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
            Color.primary.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated sparkle icon
                ZStack {
                    Circle()
                        .fill(Theme.brand.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Theme.brand.opacity(0.08))
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .rotationEffect(.degrees(sparkleRotation))
                }

                VStack(spacing: 8) {
                    Text("Deleting Files")
                        .font(.system(size: 18, weight: .bold))
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                }

                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.1))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.primaryGradient)
                                .frame(width: geo.size.width * animatedProgress)
                        }
                    }
                    .frame(height: 12)
                    .frame(maxWidth: 300)

                    if freedSoFar > 0 {
                        Text("Freed \(ByteCountFormatter.string(fromByteCount: freedSoFar, countStyle: .file))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.brand)
                    }
                }

                // Current file
                if !currentFile.isEmpty {
                    Text(currentFile)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 300)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThickMaterial)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .shadow(color: .primary.opacity(0.3), radius: 30, y: 10)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Scan Summary Card (kept for backward compatibility)
struct ScanSummaryCard: View {
    let totalFiles: Int
    let totalSize: Int64
    let selectedSize: Int64
    let categoryCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.brand)
                            Text("Scan Complete")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text("\(totalFiles) files across \(categoryCount) categories")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.brand)
                        Text("total junk found")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.brand)
                            .frame(width: 8, height: 8)
                        Text("Selected: \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button("Select All") { onSelectAll() }
                            .buttonStyle(.glass)
                            .font(.system(size: 11))
                        Button("Deselect All") { onDeselectAll() }
                            .buttonStyle(.glass)
                            .font(.system(size: 11))
                    }
                }
            }
        }
    }
}

// MARK: - JunkCategoryRow (legacy — kept for backward compatibility)
struct JunkCategoryRow: View {
    let category: JunkCategory
    let items: [JunkItem]
    let onToggle: (Bool) -> Void
    let onToggleItem: (JunkItem) -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    private var selectedCount: Int { items.filter(\.isSelected).count }
    private var catColor: Color {
        Color(red: category.color.r, green: category.color.g, blue: category.color.b)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    // Colored category icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(catColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: category.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(catColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("\(items.count) files • \(selectedCount) selected")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(catColor)

                    // Toggle category checkbox
                    Button {
                        let allSelected = selectedCount == items.count
                        onToggle(!allSelected)
                    } label: {
                        Image(systemName: selectedCount == items.count ? "checkmark.square.fill" :
                              (selectedCount > 0 ? "minus.square.fill" : "square"))
                            .foregroundStyle(selectedCount > 0 ? catColor : .secondary.opacity(0.4))
                            .font(.system(size: 18))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)

                // Select All / None row
                HStack {
                    Spacer()
                    Button("Select All") { onToggle(true) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(catColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    Text("|").foregroundStyle(.separator).font(.system(size: 11))
                    Button("Deselect All") { onToggle(false) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(catColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                LazyVStack(spacing: 0) {
                    ForEach(items.prefix(50)) { item in
                        JunkFileRow(item: item, catColor: catColor, onToggleItem: onToggleItem)
                    }
                    if items.count > 50 {
                        Text("+ \(items.count - 50) more files")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .shadow(
                color: .primary.opacity(isHovered ? 0.08 : 0.05), radius: isHovered ? 8 : 6, y: 2)
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

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

// MARK: - Individual Junk File Row (extracted for SwiftUI identity tracking)
struct JunkFileRow: View {
    let item: JunkItem
    let catColor: Color
    let onToggleItem: (JunkItem) -> Void

    var body: some View {
        Button {
            onToggleItem(item)
        } label: {
            HStack(spacing: 10) {
                Image(
                    systemName: item.isSelected
                        ? "checkmark.circle.fill" : "circle"
                )
                .foregroundStyle(
                    item.isSelected ? catColor : .secondary.opacity(0.4))
                .font(.system(size: 14))

                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary.opacity(0.6))
                    .font(.system(size: 12))

                Text(item.fileName)
                    .font(.system(size: 11))
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.primary)

                Spacer()

                Text(item.formattedSize)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                item.isSelected
                    ? catColor.opacity(0.04)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }
            Button(item.isSelected ? "Deselect" : "Select") {
                onToggleItem(item)
            }
        }
    }
}

// MARK: - Browser Cache Group Row (BuhoCleaner-style per-browser)

private struct BrowserCacheGroupRow: View {
    let browser: BrowserApp
    let items: [JunkItem]
    let onToggleItem: (JunkItem) -> Void
    let onToggleBrowser: (Bool) -> Void

    @State private var isExpanded = false
    @State private var isHovered = false

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    private var selectedCount: Int { items.filter(\.isSelected).count }
    private let browserColor = Color(red: 0.40, green: 0.38, blue: 0.82) // indigo for browser

    /// Real app icon from Finder, or nil if not installed
    private var browserIcon: NSImage? {
        let fm = FileManager.default
        if fm.fileExists(atPath: browser.appPath) {
            return NSWorkspace.shared.icon(forFile: browser.appPath)
        }
        return nil
    }

    /// Group files by their source cache directory (first path component after the scan root)
    private var groupedBySourceDir: [(dir: String, files: [JunkItem])] {
        let grouped = Dictionary(grouping: items) { item -> String in
            // Extract the cache sub-directory from the path
            // e.g., ~/Library/Caches/Google/Chrome/Default/Cache → "Default/Cache"
            let components = item.path.components(separatedBy: "/")
            // Find the "Caches" component and take 2 levels after it
            if let cachesIdx = components.firstIndex(of: "Caches") {
                let subStart = min(cachesIdx + 2, components.count - 1)
                let subEnd = min(subStart + 2, components.count - 1)
                if subStart < components.count - 1 {
                    return components[subStart..<subEnd].joined(separator: "/")
                }
            }
            return "Cache"
        }
        return grouped.map { (dir: $0.key, files: $0.value) }
            .sorted { $0.files.reduce(0) { $0 + $1.size } > $1.files.reduce(0) { $0 + $1.size } }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Browser header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    // Checkbox
                    Button {
                        onToggleBrowser(selectedCount < items.count)
                    } label: {
                        Image(systemName: selectedCount == items.count ? "checkmark.square.fill" :
                              (selectedCount > 0 ? "minus.square.fill" : "square"))
                            .foregroundStyle(selectedCount > 0 ? browserColor : .secondary.opacity(0.4))
                            .font(.system(size: 16))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Browser icon
                    if let icon = browserIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(browserColor.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: browser.fallbackIcon)
                                .font(.system(size: 13))
                                .foregroundStyle(browserColor)
                        }
                    }

                    // Browser name + file count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(browser.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(items.count) files")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Total size
                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(browserColor)

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            // Expanded content — show source directories + files
            if isExpanded {
                VStack(spacing: 0) {
                    // Sub-directory groups
                    ForEach(groupedBySourceDir.prefix(8), id: \.dir) { group in
                        VStack(spacing: 0) {
                            // Sub-directory header
                            HStack(spacing: 8) {
                                Color.clear.frame(width: 22)
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(browserColor.opacity(0.5))
                                Text(group.dir)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                let dirSize = group.files.reduce(Int64(0)) { $0 + $1.size }
                                Text(ByteCountFormatter.string(fromByteCount: dirSize, countStyle: .file))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.tertiary)
                                Text("\(group.files.count) files")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.02))

                            // Individual files (show first few per directory)
                            ForEach(group.files.prefix(20)) { item in
                                JunkFileRow(item: item, catColor: browserColor, onToggleItem: onToggleItem)
                            }
                            if group.files.count > 20 {
                                Text("+ \(group.files.count - 20) more files")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}
