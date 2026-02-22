//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

enum StartupCategory: String, CaseIterable, Identifiable {
    case loginItems = "User Login Items"
    case services = "Startup Services"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .loginItems: return "power"
        case .services: return "rocket.fill"
        }
    }
}

struct StartupManagerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var selectedCategory: StartupCategory = .loginItems
    @State private var itemToToggle: Int? = nil
    @State private var showWarning = false

    var enabledCount: Int { vm.startupItems.filter(\.isEnabled).count }

    var displayedItems: [(offset: Int, element: StartupItem)] {
        if selectedCategory == .loginItems {
            return vm.startupItems.enumerated().filter { $0.element.type == .loginItem }
        } else {
            return vm.startupItems.enumerated().filter { $0.element.type != .loginItem }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if vm.startupItems.isEmpty {
                Spacer()
                EmptyState(
                    icon: "power", title: "No Startup Items",
                    subtitle: "Click Refresh to scan Launch Agents and Daemons")
                Spacer()
            } else {
                HStack(spacing: 0) {
                    leftSidebar
                    Divider()
                    rightContent
                }
                bottomBar
            }
        }
        .onAppear { vm.scanStartupItems() }
        .alert("Disable System Service?", isPresented: $showWarning) {
            Button("Cancel", role: .cancel) { itemToToggle = nil }
            Button("Disable", role: .destructive) {
                if let idx = itemToToggle {
                    Task { await vm.toggleStartupItem(at: idx) }
                }
                itemToToggle = nil
            }
        } message: {
            if let idx = itemToToggle, idx < vm.startupItems.count {
                let item = vm.startupItems[idx]
                Text(
                    "Disabling system services like '\(item.name)' can cause background tasks, updaters, or applications to stop working properly. Are you sure you want to disable it?"
                )
            }
        }
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            SectionTitle(
                title: "Startup Items", icon: "power.circle.fill", gradient: Theme.primaryGradient)
            Spacer()
            GradientButton(
                "Refresh", icon: "arrow.clockwise", gradient: Theme.primaryGradient,
                isLoading: vm.isScanning
            ) {
                vm.scanStartupItems()
            }
        }
        .padding(28)
        .padding(.bottom, -10)
    }

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(StartupCategory.allCases) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    selectedCategory == category
                                        ? Theme.brand.opacity(0.2) : Theme.brand.opacity(0.08)
                                )
                                .frame(width: 26, height: 26)
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.brand)
                        }

                        Text(category.rawValue)
                            .font(
                                .system(
                                    size: 13,
                                    weight: selectedCategory == category ? .semibold : .regular)
                            )
                            .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                selectedCategory == category
                                    ? Color.primary.opacity(0.06) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }

    private var rightContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(selectedCategory.rawValue)
                    .font(.system(size: 20, weight: .bold))

                if selectedCategory == .services {
                    Text(
                        "Services that open automatically when you start your Mac or log in, these items run constantly in the background mostly."
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)
                } else {
                    Text(
                        "Applications that launch automatically when you log into your user account."
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)
                }

                VStack(spacing: 0) {
                    if displayedItems.isEmpty {
                        Text("No items found in this category.")
                            .foregroundStyle(.secondary)
                            .padding(40)
                    }

                    ForEach(Array(displayedItems.enumerated()), id: \.element.element.id) {
                        index, pair in
                        itemRow(index: index, pair: pair)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
    }

    private func itemRow(index: Int, pair: (offset: Int, element: StartupItem)) -> some View {
        let (idx, item) = pair
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Show actual app icon if we can resolve bundle identifier
                if let appIcon = appIconForItem(item) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 28, height: 28)
                        if item.type == .loginItem {
                            Image(systemName: "app.fill").foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "gearshape.fill").foregroundStyle(Theme.brand)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(item.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }

                Spacer()

                HStack(spacing: 8) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in
                                // Show warning when disabling a service (isEnabled is still
                                // the old value at this point — true means toggling OFF)
                                if item.isEnabled && selectedCategory == .services {
                                    itemToToggle = idx
                                    showWarning = true
                                } else {
                                    Task { await vm.toggleStartupItem(at: idx) }
                                }
                            }
                        )
                    )
                    .toggleStyle(.switch).labelsHidden().scaleEffect(0.8)

                    Text(item.isEnabled ? "Enabled" : "Disabled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.isEnabled ? Theme.success : .secondary)
                        .frame(width: 54, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // C3: Context menu on startup items
            .contextMenu {
                Button {
                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                Divider()
                Button {
                    Task { await vm.toggleStartupItem(at: idx) }
                } label: {
                    Label(item.isEnabled ? "Disable" : "Enable", systemImage: item.isEnabled ? "xmark.circle" : "checkmark.circle")
                }
            }

            if index < displayedItems.count - 1 {
                Divider().padding(.leading, 58)
            }
        }
    }

    private var bottomBar: some View {
        BottomBar {
            HStack(alignment: .center, spacing: 20) {
                Spacer()
                HStack(spacing: 6) {
                    Text("\(enabledCount)")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Items\nEnabled")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Divider().frame(height: 24)
                HStack(spacing: 6) {
                    Text("\(vm.startupItems.count)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Items\nTotal")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    /// Tries to resolve an app icon for the startup item via its bundle identifier.
    /// Falls back to searching for an .app bundle in ProgramArguments or Program paths.
    private func appIconForItem(_ item: StartupItem) -> NSImage? {
        // 1. Try bundle identifier directly
        if let bundleId = item.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // 2. Try to find an .app in the plist's path (e.g. /Applications/Chrome.app/Contents/...)
        //    Walk up from the plist's Program/ProgramArguments path to find a .app bundle
        if let bundleId = item.bundleIdentifier {
            // Many labels are like "com.google.Chrome" — try common app locations
            let possiblePaths = [
                "/Applications",
                "\(NSHomeDirectory())/Applications",
                "/System/Applications",
            ]
            for basePath in possiblePaths {
                if let apps = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                    for app in apps where app.hasSuffix(".app") {
                        let appPath = (basePath as NSString).appendingPathComponent(app)
                        if let bundle = Bundle(path: appPath),
                           bundle.bundleIdentifier == bundleId {
                            return NSWorkspace.shared.icon(forFile: appPath)
                        }
                    }
                }
            }
        }

        // 3. Try extracting .app path from the plist file itself
        let plistPath = item.path
        if let data = FileManager.default.contents(atPath: plistPath),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            var binaryPath: String?
            if let program = plist["Program"] as? String {
                binaryPath = program
            } else if let args = plist["ProgramArguments"] as? [String], let first = args.first {
                binaryPath = first
            }
            if let binary = binaryPath {
                // Walk up path to find .app bundle
                var pathURL = URL(fileURLWithPath: binary)
                while pathURL.path != "/" {
                    if pathURL.pathExtension == "app" {
                        return NSWorkspace.shared.icon(forFile: pathURL.path)
                    }
                    pathURL = pathURL.deletingLastPathComponent()
                }
            }
        }

        return nil
    }
}
