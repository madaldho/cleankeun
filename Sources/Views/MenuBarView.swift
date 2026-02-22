//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var vm: AppViewModel

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
                    Text("Pro")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.primaryGradient)
                        .cornerRadius(6)
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
                            color: Theme.brand)
                        MenuBarStatCard(
                            icon: "memorychip.fill", label: "RAM",
                            value: "\(Int(vm.memoryInfo?.usagePercentage ?? 0))%",
                            percentage: (vm.memoryInfo?.usagePercentage ?? 0) / 100,
                            color: memoryColor)
                    }

                    HStack(spacing: 12) {
                        let diskPct =
                            vm.diskTotal > 0 ? Double(vm.diskUsed) / Double(vm.diskTotal) : 0
                        MenuBarStatCard(
                            icon: "internaldrive.fill", label: "Disk",
                            value: ByteCountFormatter.string(
                                fromByteCount: vm.diskFree, countStyle: .file),
                            percentage: diskPct, color: diskPct > 0.85 ? Theme.danger : Theme.brand)

                        // Compact Network Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ZStack {
                                    Circle().fill(Theme.brand.opacity(0.2)).frame(
                                        width: 28, height: 28)
                                    Image(systemName: "network")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.brand)
                                }
                                Spacer()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down").foregroundColor(Theme.success).font(
                                        .system(size: 8, weight: .bold))
                                    Text(vm.networkInfo?.formattedDownload ?? "0 B/s")
                                        .font(
                                            .system(size: 10, weight: .medium, design: .monospaced)
                                        )
                                        .foregroundStyle(.primary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up").foregroundColor(Theme.warning).font(
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
                        )
                    }
                }
                .padding(.horizontal, 16)

                // Quick Actions (2x2 Grid)
                VStack(spacing: 10) {
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
                    HStack(spacing: 10) {
                        MenuBarAction(icon: "trash.fill", title: "Empty", color: Theme.danger) {
                            Task { let _ = await ToolkitService.shared.emptyTrash() }
                        }
                        MenuBarAction(icon: "wifi", title: "DNS", color: Theme.brand) {
                            Task { let _ = await ToolkitService.shared.flushDNS() }
                        }
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
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
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
    }

    private var memoryColor: Color {
        guard let mem = vm.memoryInfo else { return Theme.success }
        if mem.usagePercentage > 85 { return Theme.danger }
        if mem.usagePercentage > 70 { return Theme.warning }
        return Theme.success
    }

    private func openMainApp(_ nav: NavigationItem) {
        vm.selectedNav = nav
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: {
            $0.title.contains("Cleankeun") || $0.isKeyWindow
        }) {
            window.makeKeyAndOrderFront(nil)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
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
                        .foregroundColor(color)
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
