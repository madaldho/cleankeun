//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct AppUninstallerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var appToUninstall: InstalledApp? = nil
    @State private var showConfirm = false
    @State private var showLeftovers = false

    // Filters
    @State private var selectedSource: AppSource? = nil
    @State private var selectedVendor: AppVendor? = nil

    var filteredApps: [InstalledApp] {
        var apps = vm.filteredApps
        if let s = selectedSource { apps = apps.filter { $0.source == s } }
        if let v = selectedVendor { apps = apps.filter { $0.vendor == v } }
        return apps
    }

    var totalSelectedSize: Int64 {
        filteredApps.filter(\.isSelected).reduce(0) { $0 + $1.totalSize }
    }

    var selectedCount: Int {
        filteredApps.filter(\.isSelected).count
    }

    var body: some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            // Header Action Bar
            HStack {
                SectionTitle(
                    title: "App Uninstall", icon: "trash.square.fill", gradient: Theme.dangerGradient
                )
                Spacer()

                if !vm.leftovers.isEmpty {
                    Button {
                        showLeftovers.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.warning).frame(width: 6, height: 6)
                            Text("\(vm.leftovers.count) Leftovers")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                // Sort picker
                HStack(spacing: 4) {
                    Text("Sort:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { vm.appSortBy },
                        set: { vm.appSortBy = $0 }
                    )) {
                        ForEach(AppSortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Search applications...", text: $vm.appSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .frame(width: 200)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

                GradientButton(
                    "Scan Apps", icon: "magnifyingglass", gradient: Theme.primaryGradient,
                    isLoading: vm.isScanning
                ) {
                    Task { await vm.scanApps() }
                }
            }
            .padding(28)
            .padding(.bottom, -10)

            // Always show sidebar + main layout (consistent before/after scan)
            HStack(spacing: 0) {
                // Left Sidebar Filters
                VStack(alignment: .leading, spacing: 20) {
                    FilterSection(
                        title: "Sources", items: AppSource.allCases, selected: $selectedSource,
                        apps: vm.filteredApps
                    ) { $0.source == $1 }
                    FilterSection(
                        title: "Vendors", items: AppVendor.allCases, selected: $selectedVendor,
                        apps: vm.filteredApps
                    ) { $0.vendor == $1 }
                    Spacer()
                }
                .frame(width: 160)
                .padding(20)

                Divider()

                // Main App List
                ScrollView {
                    VStack(spacing: 12) {
                        if vm.installedApps.isEmpty && !vm.isScanning {
                            // Empty state within the main area (layout stays consistent)
                            VStack(spacing: 16) {
                                Spacer().frame(height: 40)
                                EmptyState(
                                    icon: "app.dashed", title: "No Apps Scanned",
                                    subtitle:
                                        "Scan to view all installed applications and remove them completely with leftover files",
                                    gradient: Theme.dangerGradient)
                                Spacer()
                            }
                        } else if vm.isScanning && vm.installedApps.isEmpty {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 40)
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Scanning applications...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Text("\(filteredApps.count) applications")
                                    .font(.system(size: 12, weight: .medium)).foregroundStyle(
                                        .secondary)
                                Spacer()
                                if !filteredApps.isEmpty {
                                    let totalSize = filteredApps.reduce(0) { $0 + $1.totalSize }
                                    Text("Total: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.brand)
                                }
                            }

                            ForEach(filteredApps) { app in
                                AppCard(
                                    app: Binding(
                                        get: {
                                            vm.installedApps.first(where: { $0.id == app.id }) ?? app
                                        },
                                        set: { newValue in
                                            if let i = vm.installedApps.firstIndex(where: {
                                                $0.id == newValue.id
                                            }) {
                                                vm.installedApps[i] = newValue
                                            }
                                        }),
                                    onUninstall: {
                                        appToUninstall = app
                                        showConfirm = true
                                    }
                                )
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                                    }
                                    Button("Uninstall \(app.name)") {
                                        appToUninstall = app
                                        showConfirm = true
                                    }
                                    Divider()
                                    Button(app.isSelected ? "Deselect" : "Select") {
                                        if let i = vm.installedApps.firstIndex(where: { $0.id == app.id }) {
                                            vm.installedApps[i].isSelected.toggle()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }

            // Bottom Action Bar when items selected
            if selectedCount > 0 {
                BottomBar {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(selectedCount) items selected")
                                .font(.system(size: 13, weight: .medium))
                            Text(
                                ByteCountFormatter.string(
                                    fromByteCount: totalSelectedSize, countStyle: .file)
                            )
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        GradientButton(
                            "Remove Selected", icon: "trash", gradient: Theme.dangerGradient
                        ) {
                            appToUninstall = nil
                            showConfirm = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showLeftovers) {
            LeftoversSheet(leftovers: vm.leftovers)
        }
        .alert(
            appToUninstall.map { "Uninstall \($0.name)?" } ?? "Uninstall Selected Apps?",
            isPresented: $showConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let app = appToUninstall {
                    Task { await vm.uninstallApp(app) }
                } else {
                    let selected = filteredApps.filter { $0.isSelected }
                    Task {
                        for app in selected {
                            await vm.uninstallApp(app)
                        }
                    }
                }
            }
        } message: {
            if let app = appToUninstall {
                Text(
                    "This will remove \(app.name) and \(app.relatedFiles.count) related files (\(app.formattedTotalSize))."
                )
            } else {
                Text(
                    "This will remove \(selectedCount) selected applications and their related files (\(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)))."
                )
            }
        }
    }
}

// MARK: - Filters
struct FilterSection<T: Equatable & RawRepresentable & Hashable>: View where T.RawValue == String {
    let title: String
    let items: [T]
    @Binding var selected: T?
    let apps: [InstalledApp]
    let filterMatcher: (InstalledApp, T) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            ForEach(items, id: \.self) { item in
                let count = apps.filter { filterMatcher($0, item) }.count
                Button {
                    if selected == item { selected = nil } else { selected = item }
                } label: {
                    HStack {
                        Text(item.rawValue)
                            .font(
                                .system(size: 12, weight: selected == item ? .semibold : .regular)
                            )
                            .foregroundStyle(selected == item ? .primary : .secondary)
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        selected == item
                            ? AnyShapeStyle(Theme.brand.opacity(0.1))
                            : AnyShapeStyle(Color.clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - App Card
struct AppCard: View {
    @Binding var app: InstalledApp
    let onUninstall: () -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button {
                    app.isSelected.toggle()
                } label: {
                    Image(systemName: app.isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(app.isSelected ? Theme.brand : .secondary.opacity(0.5))
                        .font(.system(size: 16))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let icon = app.icon {
                    Image(nsImage: icon).resizable()
                        .frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.brand.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "app").foregroundStyle(.secondary))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(app.vendor.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onUninstall) {
                    Text("Remove")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.dangerGradient, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(spacing: 0) {
                    // Group Components
                    ComponentRow(
                        name: "Bundle", size: app.bundleSize,
                        items: [RelatedFile(path: app.path, size: app.size, type: .other)])
                    if app.librarySize > 0 {
                        ComponentRow(
                            name: "Library", size: app.librarySize,
                            items: app.relatedFiles.filter { $0.group == .library })
                    }
                    if app.supportSize > 0 {
                        ComponentRow(
                            name: "Supporting Files", size: app.supportSize,
                            items: app.relatedFiles.filter { $0.group == .supportingFiles })
                    }
                    if app.preferencesSize > 0 {
                        ComponentRow(
                            name: "Preferences", size: app.preferencesSize,
                            items: app.relatedFiles.filter { $0.group == .preferences })
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .shadow(
                    color: .primary.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 8 : 4, y: 2
                )
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct ComponentRow: View {
    let name: String
    let size: Int64
    let items: [RelatedFile]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square")
                        .foregroundStyle(.secondary.opacity(0.3))
                        .font(.system(size: 12))

                    Text(name)
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(items) { item in
                    HStack {
                        Image(systemName: "square").foregroundStyle(.clear).font(.system(size: 12))
                        Image(
                            systemName: item.group == .bundle
                                ? "app.fill"
                                : (item.group == .preferences ? "doc.text.fill" : "folder.fill")
                        )
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                        Text(item.fileName)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(item.formattedSize)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 56)
                    .padding(.vertical, 3)
                }
            }
        }
    }
}

// MARK: - Leftovers Sheet
struct LeftoversSheet: View {
    let leftovers: [RelatedFile]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("App Leftovers")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }

            Text("These files belong to previously uninstalled apps")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            List(leftovers) { lf in
                HStack {
                    Text(lf.type.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    Text(lf.fileName).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    Text(lf.formattedSize).font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}
