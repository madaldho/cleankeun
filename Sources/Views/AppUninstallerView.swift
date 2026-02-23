//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

enum AppUninstallSidebarItem: Hashable {
    case all
    case leftovers
    case selected
    case largeAndOld
    case source(AppSource)
    case vendor(AppVendor)
}

struct AppUninstallerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var selectedSidebarItem: AppUninstallSidebarItem = .all
    @State private var sortOption: AppSortOption = .size
    @State private var showConfirm = false
    
    // Derived state for apps
    var appsForCurrentFilter: [InstalledApp] {
        switch selectedSidebarItem {
        case .all:
            return vm.installedApps
        case .leftovers:
            return [] // Handled separately
        case .selected:
            return vm.installedApps.filter { $0.isSelected }
        case .largeAndOld:
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            return vm.installedApps.filter { 
                $0.totalSize > 100 * 1024 * 1024 && 
                ($0.lastUsedDate ?? Date.distantPast) < threeMonthsAgo 
            }
        case .source(let src):
            return vm.installedApps.filter { $0.source == src }
        case .vendor(let ven):
            return vm.installedApps.filter { $0.vendor == ven }
        }
    }
    
    var sortedApps: [InstalledApp] {
        var apps = appsForCurrentFilter
        if !vm.appSearchText.isEmpty {
            apps = apps.filter { $0.name.localizedStandardContains(vm.appSearchText) }
        }
        switch sortOption {
        case .name:
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            apps.sort { $0.totalSize > $1.totalSize }
        case .date:
            apps.sort { ($0.lastUsedDate ?? Date.distantPast) > ($1.lastUsedDate ?? Date.distantPast) }
        }
        return apps
    }
    
    var totalSelectedSize: Int64 {
        let appsSize = vm.installedApps.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.selectedSize }
        let leftoversSize = vm.leftovers.filter(\.isSelected).reduce(Int64(0)) { $0 + $1.size }
        return appsSize + leftoversSize
    }

    var selectedCount: Int {
        let appsCount = vm.installedApps.filter(\.isSelected).count
        let leftoversCount = vm.leftovers.filter(\.isSelected).count
        return appsCount + leftoversCount
    }

    var body: some View {
        @Bindable var vm = vm
        
        VStack(spacing: 0) {
            // Top Toolbar
            topToolbar
            
            Divider()
            
            if vm.installedApps.isEmpty && !vm.isScanningApps {
                emptyView
            } else {
                HStack(spacing: 0) {
                    // Left Sidebar
                    leftSidebar
                    
                    Divider()
                    
                    // Main Content
                    mainContent
                }
            }
            
            Divider()
            
            // Bottom Bar
            bottomBar
        }
        .onAppear {
            if vm.installedApps.isEmpty && !vm.isScanningApps {
                Task { await vm.scanApps() }
            }
        }
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            Button {
                Task { await vm.scanApps() } // Refresh/Start over
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .accessibilityLabel("Back to App List")
                    Text("Start Over")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("App Uninstall")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: Binding(get: { vm.appSearchText }, set: { vm.appSearchText = $0 }))
                    .textFieldStyle(.plain)
                    .frame(width: 120)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Main categories
                VStack(spacing: 4) {
                    sidebarRow(title: "All Applications", icon: "square.grid.2x2", count: vm.installedApps.count, item: .all)
                    sidebarRow(title: "Leftovers", icon: "square.stack.3d.up", count: vm.leftovers.count, item: .leftovers)
                    sidebarRow(title: "Selected", icon: "checkmark.circle", count: selectedCount, item: .selected)
                }
                
                // Large and Old
                let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                let largeOldCount = vm.installedApps.filter { $0.totalSize > 100 * 1024 * 1024 && ($0.lastUsedDate ?? Date.distantPast) < threeMonthsAgo }.count
                if largeOldCount > 0 {
                    VStack(spacing: 4) {
                        sidebarRow(title: "Large and Old", count: largeOldCount, item: .largeAndOld, isHighlighted: true)
                    }
                }
                
                // Sources
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sources")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    
                    ForEach(AppSource.allCases) { source in
                        let count = vm.installedApps.filter { $0.source == source }.count
                        if count > 0 {
                            sidebarRow(title: source.rawValue, count: count, item: .source(source))
                        }
                    }
                }
                
                // Vendors
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vendors")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    
                    ForEach(AppVendor.allCases) { vendor in
                        let count = vm.installedApps.filter { $0.vendor == vendor }.count
                        if count > 0 {
                            sidebarRow(title: vendor.rawValue, count: count, item: .vendor(vendor))
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func sidebarRow(title: String, icon: String? = nil, count: Int, item: AppUninstallSidebarItem, isHighlighted: Bool = false) -> some View {
        let isSelected = selectedSidebarItem == item
        return Button {
            selectedSidebarItem = item
        } label: {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .frame(width: 16)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? (isHighlighted ? Theme.brand : Theme.brand.opacity(0.8)) : (isHighlighted ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headerTitle)
                        .font(.system(size: 18, weight: .bold))
                    Text(headerSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                if selectedSidebarItem != .leftovers {
                    Menu {
                        Picker("", selection: $sortOption) {
                            ForEach(AppSortOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        Text("Sort by \(sortOption.rawValue)")
                            .font(.system(size: 12))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(24)
            
            // List
            if vm.isScanningApps {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Scanning applications...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if selectedSidebarItem == .leftovers {
                            leftoversList
                        } else {
                            if sortedApps.isEmpty {
                                Text("No applications found.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 40)
                            } else {
                                ForEach(sortedApps) { app in
                                    AppTreeCard(
                                        app: Binding(
                                            get: { vm.installedApps.first(where: { $0.id == app.id }) ?? app },
                                            set: { newVal in
                                                if let idx = vm.installedApps.firstIndex(where: { $0.id == app.id }) {
                                                    vm.installedApps[idx] = newVal
                                                }
                                            }
                                        ),
                                        showDate: selectedSidebarItem == .largeAndOld
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerTitle: String {
        switch selectedSidebarItem {
        case .all: return "All Applications"
        case .leftovers: return "Leftovers"
        case .selected: return "Selected Items"
        case .largeAndOld: return "Large and Old"
        case .source(let s): return "\(s.rawValue) Apps"
        case .vendor(let v): return "Apps by \(v.rawValue)"
        }
    }
    
    private var headerSubtitle: String {
        switch selectedSidebarItem {
        case .all: return "Apps installed on your Mac are listed here."
        case .leftovers: return "Files left behind by previously uninstalled apps."
        case .selected: return "Items you have selected for removal."
        case .largeAndOld: return "Apps larger than 100 MB and have not been opened in the past 3 months."
        case .source: return "Apps grouped by where they were downloaded from."
        case .vendor: return "Apps grouped by their developer."
        }
    }
    
    // MARK: - Leftovers List
    private var leftoversList: some View {
        VStack(spacing: 0) {
            ForEach(vm.leftovers) { leftover in
                HStack(spacing: 12) {
                    Button {
                        if let idx = vm.leftovers.firstIndex(where: { $0.id == leftover.id }) {
                            vm.leftovers[idx].isSelected.toggle()
                        }
                    } label: {
                        Image(systemName: leftover.isSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(leftover.isSelected ? Theme.brand : .secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leftover.fileName)
                            .font(.system(size: 13, weight: .medium))
                        Text(leftover.path)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
                    Text(leftover.formattedSize)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(totalSelectedSize > 0 ? ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file) : "0 Byte")")
                    .font(.system(size: 24, weight: .regular))
                Text("Selected")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 16)
            
            let totalAllSize = vm.installedApps.reduce(Int64(0)) { $0 + $1.totalSize } + vm.leftovers.reduce(Int64(0)) { $0 + $1.size }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(ByteCountFormatter.string(fromByteCount: totalAllSize, countStyle: .file))")
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
                    .background(totalSelectedSize > 0 ? Theme.brand : Color.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(totalSelectedSize == 0)
            .confirmationDialog(
                "Uninstall Selected Apps?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Uninstall Permanently", role: .destructive) {
                    Task {
                        let appsToRemove = vm.installedApps.filter { $0.isSelected }
                        for app in appsToRemove {
                            await vm.uninstallApp(app)
                        }
                        
                        let leftoversToRemove = vm.leftovers.filter { $0.isSelected }
                        if !leftoversToRemove.isEmpty {
                            await vm.removeLeftovers(leftoversToRemove)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action will permanently delete \(vm.installedApps.filter { $0.isSelected }.count) apps and \(vm.leftovers.filter { $0.isSelected }.count) leftovers. This cannot be undone.")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.slash")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No Applications Scanned")
                .font(.system(size: 18, weight: .bold))
            Button("Scan Now") {
                Task { await vm.scanApps() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - App Tree Card
struct AppTreeCard: View {
    @Binding var app: InstalledApp
    let showDate: Bool
    
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Main App Row
            HStack(spacing: 12) {
                Button {
                    app.isSelected.toggle()
                } label: {
                    Image(systemName: app.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(app.isSelected ? Theme.brand : .secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.brand.opacity(0.5))
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .medium))
                    
                    if showDate, let date = app.lastUsedDate {
                        Text(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(app.formattedTotalSize)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(app.isSelected ? Theme.brand.opacity(0.1) : (isHovered ? Color.primary.opacity(0.03) : Color.primary.opacity(0.01)))
            )
            .onHover { isHovered = $0 }
            
            // Expanded Tree View
            if isExpanded {
                VStack(spacing: 0) {
                    // Bundle
                    ComponentGroupRow(
                        title: "Bundle",
                        app: $app,
                        group: .bundle,
                        isBundle: true
                    )
                    
                    // Library
                    if app.relatedFiles.contains(where: { $0.group == .library }) {
                        ComponentGroupRow(title: "Library", app: $app, group: .library, isBundle: false)
                    }
                    
                    // Supporting Files
                    if app.relatedFiles.contains(where: { $0.group == .supportingFiles }) {
                        ComponentGroupRow(title: "Supporting Files", app: $app, group: .supportingFiles, isBundle: false)
                    }
                    
                    // Caches
                    if app.relatedFiles.contains(where: { $0.group == .caches }) {
                        ComponentGroupRow(title: "Caches", app: $app, group: .caches, isBundle: false)
                    }
                    
                    // Preferences
                    if app.relatedFiles.contains(where: { $0.group == .preferences }) {
                        ComponentGroupRow(title: "Preferences", app: $app, group: .preferences, isBundle: false)
                    }
                }
                .padding(.leading, 32)
                .padding(.trailing, 12)
                .padding(.bottom, 12)
            }
        }
    }
}

struct ComponentGroupRow: View {
    let title: String
    @Binding var app: InstalledApp
    let group: AppComponentGroup
    let isBundle: Bool
    
    @State private var isExpanded = false
    
    var groupFiles: [RelatedFile] {
        app.relatedFiles.filter { $0.group == group }
    }
    
    var isAllSelected: Bool {
        if isBundle { return app.isBundleSelected }
        let files = groupFiles
        return !files.isEmpty && files.allSatisfy { $0.isSelected }
    }
    
    var groupSize: Int64 {
        if isBundle { return app.bundleSize }
        return groupFiles.reduce(Int64(0)) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group Header Row
            HStack(spacing: 12) {
                Button {
                    let newState = !isAllSelected
                    if isBundle {
                        app.isBundleSelected = newState
                    } else {
                        for i in app.relatedFiles.indices where app.relatedFiles[i].group == group {
                            app.relatedFiles[i].isSelected = newState
                        }
                    }
                } label: {
                    Image(systemName: isAllSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isAllSelected ? Theme.brand : .secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: groupSize, countStyle: .file))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                
                if !isBundle {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            
            // Files under group
            if isExpanded || isBundle {
                if isBundle {
                    fileRow(
                        path: app.path,
                        fileName: (app.path as NSString).lastPathComponent,
                        size: app.size,
                        isSelected: app.isBundleSelected,
                        onToggle: { app.isBundleSelected.toggle() }
                    )
                } else {
                    // Because we need bindings to the array items safely
                    ForEach(app.relatedFiles.indices, id: \.self) { i in
                        if app.relatedFiles[i].group == group {
                            fileRow(
                                path: app.relatedFiles[i].path,
                                fileName: app.relatedFiles[i].fileName,
                                size: app.relatedFiles[i].size,
                                isSelected: app.relatedFiles[i].isSelected,
                                onToggle: { app.relatedFiles[i].isSelected.toggle() }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func fileRow(path: String, fileName: String, size: Int64, isSelected: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Theme.brand : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: 16, height: 16)
            
            Text(fileName)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
                
            Button {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "magnifyingglass.circle")
                    .accessibilityLabel("Search Apps")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.leading, 24)
        .padding(.vertical, 4)
    }
}
