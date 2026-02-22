//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct ToolkitView: View {
    @Environment(AppViewModel.self) var vm
    @State private var toolResults: [String: ToolResult] = [:]
    @State private var showTrashConfirm = false
    @State private var showBrowserConfirm = false
    @State private var showSpotlightConfirm = false
    @State private var showLaunchServicesConfirm = false
    @State private var showPurgeableConfirm = false
    @State private var trashItemCount = 0
    @State private var trashSize: Int64 = 0
    @State private var trashAccessDenied = false
    @State private var toastMessage: String? = nil

    var body: some View {
        ZStack {
            toolkitContent

            // Toast notification overlay
            if let toast = toastMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                        Text(toast)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThickMaterial)
                            .glassEffect(.regular, in: .rect(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .padding(.top, 12)
                .zIndex(100)
            }
        }
        .onAppear { refreshTrashInfo() }
        // Trash confirmation
        .alert("Empty Trash?", isPresented: $showTrashConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Empty Trash", role: .destructive) {
                Task {
                    await runTool("trash") { await ToolkitService.shared.emptyTrash() }
                    refreshTrashInfo()
                }
            }
        } message: {
            if trashAccessDenied {
                Text("Cleankeun can't read the Trash directly, but Finder can empty it. Proceed?")
            } else {
                Text("Permanently delete \(trashItemCount) items (\(ByteCountFormatter.string(fromByteCount: trashSize, countStyle: .file)))? This cannot be undone.")
            }
        }
        // Browser cache confirmation
        .alert("Clear Browser Data?", isPresented: $showBrowserConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Data", role: .destructive) {
                Task {
                    await runTool("browser") { await ToolkitService.shared.clearBrowserData() }
                    showToast("Browser cache cleared successfully")
                }
            }
        } message: {
            Text("This will clear cached data from Safari, Chrome, Firefox, and Arc. Websites may load slower temporarily as caches are rebuilt. Bookmarks and passwords are not affected.")
        }
        // Spotlight confirmation
        .alert("Rebuild Spotlight Index?", isPresented: $showSpotlightConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Rebuild", role: .destructive) {
                Task {
                    await runTool("spotlight") { await ToolkitService.shared.rebuildSpotlight() }
                    showToast("Spotlight reindex started — may take several minutes in the background")
                }
            }
        } message: {
            Text("This will erase and rebuild the entire Spotlight search index. Requires administrator password. Spotlight search may be slow or incomplete until reindexing finishes (can take 10-30 minutes).")
        }
        // Launch Services confirmation
        .alert("Rebuild Launch Services?", isPresented: $showLaunchServicesConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Rebuild") {
                Task {
                    await runTool("launchservices") { await ToolkitService.shared.rebuildLaunchServices() }
                    showToast("Launch Services database rebuilt")
                }
            }
        } message: {
            Text("This fixes the \"Open With\" menu when it shows duplicate apps or wrong file associations. The database will be rebuilt — Finder may momentarily refresh.")
        }
        // Purgeable space confirmation
        .alert("Free Purgeable Disk Space?", isPresented: $showPurgeableConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Free Space") {
                Task {
                    await runTool("purgeable") { await ToolkitService.shared.freePurgeableSpace() }
                    showToast("Purgeable space reclaimed")
                }
            }
        } message: {
            Text("macOS keeps purgeable data (old caches, Time Machine snapshots) that can be reclaimed when disk space is low. This forces macOS to release that space now. Requires administrator password.")
        }
    }

    private var toolkitContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionTitle(
                    title: "Toolkit", icon: "wrench.and.screwdriver.fill",
                    gradient: Theme.primaryGradient)

                // System info card
                GlassCard {
                    HStack(spacing: 16) {
                        InfoChip(
                            icon: "desktopcomputer", label: "Model",
                            value: ToolkitService.shared.getMachineModel(),
                            color: Theme.brand)
                        InfoChip(
                            icon: "applelogo", label: "macOS",
                            value: ToolkitService.shared.getMacOSVersion(),
                            color: Theme.brandDark)
                        InfoChip(
                            icon: "clock", label: "Uptime",
                            value: ToolkitService.shared.getSystemUptime(),
                            color: Theme.warning)
                        InfoChip(
                            icon: "cpu", label: "Cores",
                            value: "\(ProcessInfo.processInfo.processorCount)",
                            color: Theme.brandLight)
                    }
                }

                // Tool cards grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16),
                    ], spacing: 16
                ) {
                    ToolCard(
                        icon: "safari.fill",
                        title: "Clear Browser Cache",
                        description: "Clear cached data from Safari, Chrome, Firefox, and Arc. Bookmarks and passwords are not affected.",
                        color: Theme.brand,
                        result: toolResults["browser"]
                    ) {
                        showBrowserConfirm = true
                    }

                    ToolCard(
                        icon: "magnifyingglass.circle.fill",
                        title: "Rebuild Spotlight",
                        description: "Reindex Spotlight search database. Fixes missing search results and slow queries. Takes 10-30 min in background.",
                        color: Theme.brandDark,
                        result: toolResults["spotlight"]
                    ) {
                        showSpotlightConfirm = true
                    }

                    ToolCard(
                        icon: "app.badge.checkmark",
                        title: "Rebuild Launch Services",
                        description: "Fix duplicate entries in the \"Open With\" right-click menu and resolve wrong file type associations.",
                        color: Theme.warning,
                        result: toolResults["launchservices"]
                    ) {
                        showLaunchServicesConfirm = true
                    }

                    ToolCard(
                        icon: "trash.circle.fill",
                        title: "Empty Trash",
                        description: trashDescription,
                        color: Theme.danger,
                        result: toolResults["trash"]
                    ) {
                        let info = ToolkitService.shared.getTrashInfo()
                        trashItemCount = info.itemCount
                        trashSize = info.totalSize
                        trashAccessDenied = info.accessDenied
                        if !info.accessDenied && info.itemCount == 0 {
                            toolResults["trash"] = ToolResult(state: .success, message: "Trash is already empty")
                        } else {
                            showTrashConfirm = true
                        }
                    }

                    ToolCard(
                        icon: "internaldrive.fill",
                        title: "Free Purgeable Space",
                        description: "Reclaim disk space held by macOS as purgeable (old caches, Time Machine snapshots). Requires admin password.",
                        color: Theme.success,
                        result: toolResults["purgeable"]
                    ) {
                        showPurgeableConfirm = true
                    }

                    ToolCard(
                        icon: "memorychip.fill",
                        title: "Optimize Memory",
                        description: "Free up inactive RAM and compressed pages to improve responsiveness when your Mac feels sluggish.",
                        color: Theme.brand,
                        result: toolResults["memory"]
                    ) {
                        await runTool("memory") {
                            let result = await MemoryService.shared.optimizeMemory()
                            let freed = Int64(result.before.used) - Int64(result.after.used)
                            if freed > 0 {
                                return (
                                    true,
                                    "Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .memory))"
                                )
                            }
                            return (true, "Memory optimized")
                        }
                        showToast("Memory optimization complete")
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    private var trashDescription: String {
        let info = ToolkitService.shared.getTrashInfo()
        if info.accessDenied {
            return "Empty Trash via Finder. Grant Full Disk Access for detailed info."
        }
        if info.itemCount == 0 {
            return "Trash is empty — nothing to clean."
        }
        let size = ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file)
        return "\(info.itemCount) items in Trash (\(size)). Permanently delete to free disk space."
    }

    private func refreshTrashInfo() {
        let info = ToolkitService.shared.getTrashInfo()
        trashItemCount = info.itemCount
        trashSize = info.totalSize
        trashAccessDenied = info.accessDenied
    }

    private func showToast(_ message: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }

    private func runTool(
        _ key: String, action: @escaping () async -> (success: Bool, message: String)
    ) async {
        toolResults[key] = ToolResult(state: .running, message: "Running...")
        let result = await action()
        toolResults[key] = ToolResult(
            state: result.success ? .success : .failed,
            message: result.message
        )
    }
}

// MARK: - Tool Result Model
struct ToolResult {
    enum State { case running, success, failed }
    let state: State
    let message: String
}

// MARK: - Tool Card
struct ToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let result: ToolResult?
    let action: () async -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if let result = result {
                        resultLabel(result)
                    }
                }
                Spacer()
            }

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button {
                    Task { await action() }
                } label: {
                    HStack(spacing: 5) {
                        if result?.state == .running {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 12, height: 12)
                            Text("Running...")
                                .font(.system(size: 11, weight: .semibold))
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                            Text("Run")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        result?.state == .running
                            ? AnyShapeStyle(Color.gray)
                            : AnyShapeStyle(color),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(result?.state == .running)
            }
        }
        .padding(16)
        .frame(minHeight: 170)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .shadow(
                    color: .primary.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 8 : 4, y: 2)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func resultLabel(_ result: ToolResult) -> some View {
        switch result.state {
        case .running:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text("Running...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.warning)
            }
        case .success:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.success)
                Text(result.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.success)
                    .lineLimit(1)
            }
        case .failed:
            HStack(spacing: 3) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.danger)
                Text(result.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.danger)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Info Chip
struct InfoChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
