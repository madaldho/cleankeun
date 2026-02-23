//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(AppViewModel.self) var vm

    var body: some View {
        ZStack {
            // Native Glass Control Center Background
            Rectangle().fill(.regularMaterial).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    CleankeunLogo(size: 18)
                        .padding(.trailing, 2)
                    Text("Cleankeun")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Stats Grid (Control Center Style)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        MenuBarStatCard(
                            icon: "cpu", label: "CPU",
                            value: "\(Int(vm.cpuInfo?.usagePercentage ?? 0))%",
                            percentage: (vm.cpuInfo?.usagePercentage ?? 0) / 100,
                            color: Theme.brand,
                            subtitle: vm.cpuInfo?.temperature.map { String(format: "%.0f°C", $0) })
                        MenuBarStatCard(
                            icon: "memorychip.fill", label: "RAM",
                            value: "\(Int(vm.memoryInfo?.usagePercentage ?? 0))%",
                            percentage: (vm.memoryInfo?.usagePercentage ?? 0) / 100,
                            color: memoryColor,
                            subtitle: nil)
                    }

                    HStack(spacing: 12) {
                        let diskPct =
                            vm.diskTotal > 0 ? Double(vm.diskUsed) / Double(vm.diskTotal) : 0
                        MenuBarStatCard(
                            icon: "internaldrive.fill", label: "Disk",
                            value: ByteCountFormatter.string(
                                fromByteCount: vm.diskFree, countStyle: .file),
                            percentage: diskPct, color: diskPct > 0.85 ? Theme.danger : Theme.brand,
                            subtitle: nil)

                        // Compact Network Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ZStack {
                                    Circle().fill(Theme.brand.opacity(0.2)).frame(
                                        width: 28, height: 28)
                                    Image(systemName: "network")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.brand)
                                }
                                Spacer()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down").foregroundStyle(Theme.success).font(
                                        .system(size: 8, weight: .bold))
                                    Text(vm.networkInfo?.formattedDownload ?? "0 B/s")
                                        .font(
                                            .system(size: 10, weight: .medium, design: .monospaced)
                                        )
                                        .foregroundStyle(.primary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up").foregroundStyle(Theme.warning).font(
                                        .system(size: 8, weight: .bold))
                                    Text(vm.networkInfo?.formattedUpload ?? "0 B/s")
                                        .font(
                                            .system(size: 10, weight: .medium, design: .monospaced)
                                        )
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.fill.quaternary)
                                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                        )
                    }
                }
                .padding(.horizontal, 16)

                // Trash Action
                MenuBarTrashAction(
                    size: vm.trashTotalSize,
                    itemCount: vm.trashItemCount,
                    accessDenied: vm.menuBarTrashAccessDenied
                ) {
                    _ = await ToolkitService.shared.emptyTrash()
                    await vm.refreshSystemInfo()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Quick Actions
                HStack(spacing: 10) {
                    MenuBarAction(icon: "bolt.fill", title: "Clean", color: Theme.brand)
                    {
                        openMainApp(.junkCleaner)
                    }
                    MenuBarAction(
                        icon: "m.square.fill", title: "Memory", color: Theme.brand
                    ) {
                        Task { await vm.optimizeMemory() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Divider()

                // Bottom Bar Actions
                HStack {
                    Button(action: { openMainApp(.dashboard) }) {
                        Text("Open Full App")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(.fill.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Theme.danger.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 320)
        .onAppear { vm.startMonitoring() }
        .onDisappear { vm.stopMonitoring() }
    }

    private var memoryColor: Color {
        guard let mem = vm.memoryInfo else { return Theme.success }
        if mem.usagePercentage > 85 { return Theme.danger }
        if mem.usagePercentage > 70 { return Theme.warning }
        return Theme.success
    }

    private func openMainApp(_ nav: NavigationItem) {
        vm.selectedNav = nav

        // Ensure the app shows as a regular app (Dock icon, can receive focus)
        NSApplication.shared.setActivationPolicy(.regular)
        // L2: Use non-deprecated activate()
        NSApplication.shared.activate()

        // Find the main window — exclude menu bar panels and sheets
        // Main WindowGroup window is the one that canBecomeMain
        if let mainWindow = NSApplication.shared.windows.first(where: {
            $0.canBecomeMain
        }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // If the window was closed, open a new one via the WindowGroup
            // On macOS 26+, we can use the environment openWindow action,
            // but for now just bring the app to front — SwiftUI will re-create the window.
            // L2: Use non-deprecated activate()
            NSApplication.shared.activate()
        }
    }
}

// MARK: - Menu Bar Stat Card
struct MenuBarStatCard: View {
    let icon: String
    let label: String
    let value: String
    let percentage: Double
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * min(CGFloat(percentage), 1.0))
                            .animation(.easeInOut(duration: 0.5), value: percentage)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.fill.quaternary)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        )
    }
}

// MARK: - Menu Bar Action Button
struct MenuBarAction: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Menu Bar Trash Action
struct MenuBarTrashAction: View {
    let size: Int64
    let itemCount: Int
    let accessDenied: Bool
    let action: () async -> Void

    @State private var isHovered = false
    @State private var isCleaning = false

    var body: some View {
        let isReady = accessDenied || size > 0 || itemCount > 0
        let color = isReady ? Theme.danger : Theme.success
        
        Button {
            if isReady && !isCleaning {
                confirmAndEmpty()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 32, height: 32)
                    Image(systemName: isReady ? "trash.fill" : "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if accessDenied {
                        Text("Empty Trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Empty via Finder (Need Access for details)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(isReady ? "Empty Trash" : "Trash is Empty")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(isReady ? "\(itemCount) items • \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))" : "System is clean")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                
                if isCleaning {
                    ProgressView().controlSize(.small)
                } else if isReady {
                    Text("Clean")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(color)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHovered && isReady ? AnyShapeStyle(color.opacity(0.1)) : AnyShapeStyle(.quaternary))
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    private func confirmAndEmpty() {
        let alert = NSAlert()
        alert.messageText = "Empty Trash?"
        if accessDenied {
            alert.informativeText = "Are you sure you want to empty the Trash via Finder? This cannot be undone."
        } else {
            alert.informativeText = "Are you sure you want to permanently delete \(itemCount) items (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))? This cannot be undone."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")
        // Style the destructive button
        alert.buttons.first?.hasDestructiveAction = true
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            isCleaning = true
            Task {
                await action()
                isCleaning = false
            }
        }
    }
}
