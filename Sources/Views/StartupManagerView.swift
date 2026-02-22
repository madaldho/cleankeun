//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct StartupManagerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var selectedType: StartupType = .loginItem
    @State private var itemToToggle: Int? = nil
    @State private var showWarning = false
    @State private var iconCache: [String: NSImage] = [:]  // path → icon
    @State private var searchText = ""

    var enabledCount: Int { vm.startupItems.filter(\.isEnabled).count }

    /// Items filtered by type + search, paired with their original index in vm.startupItems
    var displayedItems: [(originalIndex: Int, item: StartupItem)] {
        vm.startupItems.enumerated().compactMap { idx, item in
            guard item.type == selectedType else { return nil }
            if !searchText.isEmpty {
                let matches = item.name.localizedCaseInsensitiveContains(searchText)
                    || (item.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || item.path.localizedCaseInsensitiveContains(searchText)
                if !matches { return nil }
            }
            return (idx, item)
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
                    subtitle: "Click Refresh to scan Login Items, Launch Agents, and Daemons")
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
            if selectedType == .loginItem {
                Button {
                    // Open System Settings → Login Items
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                            .font(.system(size: 10))
                        Text("System Settings")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Theme.brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
            }
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
            ForEach(StartupType.allCases) { type in
                let count = vm.startupItems.filter { $0.type == type }.count
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedType = type
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    selectedType == type
                                        ? Theme.brand.opacity(0.2) : Theme.brand.opacity(0.08)
                                )
                                .frame(width: 26, height: 26)
                            Image(systemName: iconForType(type))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.brand)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.rawValue)
                                .font(
                                    .system(
                                        size: 13,
                                        weight: selectedType == type ? .semibold : .regular)
                                )
                                .foregroundStyle(selectedType == type ? .primary : .secondary)
                            Text("\(count) items")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                selectedType == type
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

    private func iconForType(_ type: StartupType) -> String {
        switch type {
        case .loginItem: return "person.fill"
        case .launchAgent: return "gearshape.2.fill"
        case .launchDaemon: return "server.rack"
        }
    }

    private var rightContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedType.rawValue + "s")
                    .font(.system(size: 20, weight: .bold))

                Text(descriptionForType(selectedType))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("Search startup items...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                )

                VStack(spacing: 0) {
                    if displayedItems.isEmpty {
                        Text(searchText.isEmpty ? "No items found in this category." : "No items match '\(searchText)'")
                            .foregroundStyle(.secondary)
                            .padding(40)
                    }

                    let items = displayedItems
                    ForEach(items.indices, id: \.self) { listIndex in
                        let idx = items[listIndex].originalIndex
                        let item = items[listIndex].item
                        itemRow(listIndex: listIndex, totalCount: items.count, idx: idx, item: item)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12)))
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
    }

    private func descriptionForType(_ type: StartupType) -> String {
        switch type {
        case .loginItem: return "Apps that open automatically whenever you log in to your Mac. These include apps registered via Login Items settings and embedded helper apps."
        case .launchAgent: return "Background services that run under your user account. These launch agents handle updates, syncing, and other per-user tasks."
        case .launchDaemon: return "System-level services that run in the background regardless of user login. Be cautious when disabling these."
        }
    }

    private func itemRow(listIndex: Int, totalCount: Int, idx: Int, item: StartupItem) -> some View {
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Show cached app icon, resolve lazily
                if let cachedIcon = iconCache[item.path] {
                    Image(nsImage: cachedIcon)
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
                    .onAppear {
                        let itemCopy = item
                        Task.detached(priority: .utility) {
                            let icon = resolveIconForItem(itemCopy)
                            if let icon = icon {
                                await MainActor.run {
                                    iconCache[itemCopy.path] = icon
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .medium))

                        // Vendor badge
                        Text(item.vendorLabel)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(item.isApple ? .secondary : Theme.brand)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(item.isApple ? Color.secondary.opacity(0.1) : Theme.brand.opacity(0.1))
                            )

                        // Impact badge
                        let impactColor = Color(red: item.impact.color.r, green: item.impact.color.g, blue: item.impact.color.b)
                        Text(item.impact.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(impactColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(impactColor.opacity(0.1))
                            )
                    }
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
                                if item.isEnabled && item.type != .loginItem {
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

            if listIndex < totalCount - 1 {
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
    /// Runs off the main thread — called from Task.detached and cached.
    private nonisolated func resolveIconForItem(_ item: StartupItem) -> NSImage? {
        // 1. Try bundle identifier directly via Launch Services
        if let bundleId = item.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // 2. Try extracting .app path from the plist file itself (Program / ProgramArguments)
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
                // If binary exists, use its file icon (e.g. a daemon binary)
                if FileManager.default.fileExists(atPath: binary) {
                    return NSWorkspace.shared.icon(forFile: binary)
                }
            }
        }

        // 3. Try to match by scanning /Applications for matching bundle identifier
        if let bundleId = item.bundleIdentifier {
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

            // 4. Try fuzzy match: extract last component of reverse-domain label
            let parts = bundleId.components(separatedBy: ".")
            if parts.count >= 2 {
                let candidates = parts.dropFirst().map { $0.capitalized }
                for basePath in possiblePaths {
                    if let apps = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                        for candidate in candidates {
                            for app in apps where app.hasSuffix(".app") {
                                let appName = (app as NSString).deletingPathExtension
                                if appName.localizedCaseInsensitiveCompare(candidate) == .orderedSame {
                                    let appPath = (basePath as NSString).appendingPathComponent(app)
                                    return NSWorkspace.shared.icon(forFile: appPath)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 5. Try matching item name against installed apps
        let itemNameLower = item.name.lowercased()
        let searchPaths = ["/Applications", "\(NSHomeDirectory())/Applications", "/System/Applications"]
        for basePath in searchPaths {
            if let apps = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                for app in apps where app.hasSuffix(".app") {
                    let appName = (app as NSString).deletingPathExtension.lowercased()
                    if itemNameLower.contains(appName) || appName.contains(itemNameLower) {
                        let appPath = (basePath as NSString).appendingPathComponent(app)
                        return NSWorkspace.shared.icon(forFile: appPath)
                    }
                }
            }
        }

        return nil
    }
}
