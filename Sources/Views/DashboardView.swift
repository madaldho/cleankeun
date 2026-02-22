//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppViewModel.self) var vm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionTitle(
                    title: "Dashboard", icon: "sparkles.square.filled.on.square",
                    gradient: Theme.primaryGradient)

                // Top gauges row
                HStack(spacing: 16) {
                    // Health Score Gauge
                    GlassCard {
                        VStack(spacing: 12) {
                            let scoreColor = vm.healthScoreColor
                            let gradient = LinearGradient(
                                colors: [
                                    Color(red: scoreColor.r, green: scoreColor.g, blue: scoreColor.b),
                                    Color(red: scoreColor.r, green: scoreColor.g, blue: scoreColor.b).opacity(0.6),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            AnimatedCircularGauge(
                                value: Double(vm.systemHealthScore) / 100,
                                lineWidth: 10, gradient: gradient, size: 80
                            )
                            .overlay {
                                VStack(spacing: 1) {
                                    Text("\(vm.systemHealthScore)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Text("Health")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(vm.systemHealthScore >= 80 ? "Good" : vm.systemHealthScore >= 50 ? "Fair" : "Poor")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(
                                    Color(red: scoreColor.r, green: scoreColor.g, blue: scoreColor.b))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // CPU Gauge
                    GlassCard {
                        VStack(spacing: 12) {
                            AnimatedCircularGauge(
                                value: (vm.cpuInfo?.usagePercentage ?? 0) / 100,
                                lineWidth: 10, gradient: Theme.primaryGradient, size: 80
                            )
                            .overlay {
                                VStack(spacing: 1) {
                                    Text("\(Int(vm.cpuInfo?.usagePercentage ?? 0))%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Text("CPU")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 4) {
                                Text("\(vm.cpuInfo?.coreCount ?? 0) Cores")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                if let temp = vm.cpuInfo?.temperature {
                                    Text("•")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.quaternary)
                                    Text(String(format: "%.0f°C", temp))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(temp > 80 ? Theme.danger : Theme.success)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // RAM Gauge
                    GlassCard {
                        VStack(spacing: 12) {
                            AnimatedCircularGauge(
                                value: (vm.memoryInfo?.usagePercentage ?? 0) / 100,
                                lineWidth: 10, gradient: Theme.successGradient, size: 80
                            )
                            .overlay {
                                VStack(spacing: 1) {
                                    Text("\(Int(vm.memoryInfo?.usagePercentage ?? 0))%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Text("RAM")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(vm.memoryInfo?.formattedUsed ?? "N/A")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Disk Gauge
                    GlassCard {
                        VStack(spacing: 12) {
                            let diskPct =
                                vm.diskTotal > 0 ? Double(vm.diskUsed) / Double(vm.diskTotal) : 0
                            AnimatedCircularGauge(
                                value: diskPct,
                                lineWidth: 10,
                                gradient: diskPct > 0.85
                                    ? Theme.dangerGradient : Theme.primaryGradient,
                                size: 80
                            )
                            .overlay {
                                VStack(spacing: 1) {
                                    Text("\(Int(diskPct * 100))%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                    Text("Disk")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(
                                "\(ByteCountFormatter.string(fromByteCount: vm.diskFree, countStyle: .file)) free"
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Network
                    GlassCard {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Theme.brand.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Theme.brand)
                                    Text("Network")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 12) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Theme.success)
                                    Text(vm.networkInfo?.formattedDownload ?? "0 B/s")
                                        .font(
                                            .system(
                                                size: 9, weight: .medium, design: .monospaced))
                                }
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 8))
                                        .foregroundStyle(Theme.warning)
                                    Text(vm.networkInfo?.formattedUpload ?? "0 B/s")
                                        .font(
                                            .system(
                                                size: 9, weight: .medium, design: .monospaced))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Recommendations (Feature 2)
                if !vm.healthRecommendations.isEmpty && vm.systemHealthScore < 80 {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.warning)
                                Text("Recommendations")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            ForEach(vm.healthRecommendations.indices, id: \.self) { idx in
                                let rec = vm.healthRecommendations[idx]
                                HStack(spacing: 8) {
                                    Image(systemName: rec.icon)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    Text(rec.text)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Storage Bar (Feature 7 — macOS System Settings style with expandable cards)
                StorageOverviewCard()

                // Quick Actions
                Text("Quick Actions")
                    .font(.system(size: 14, weight: .semibold))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                    spacing: 12
                ) {
                    QuickAction(icon: "bolt.circle.fill", title: "Flash Clean") {
                        vm.selectedNav = .junkCleaner
                    }
                    QuickAction(icon: "memorychip.fill", title: "Free Memory") {
                        vm.selectedNav = .memory
                    }
                    QuickAction(icon: "arrow.up.doc.fill", title: "Large Files") {
                        vm.selectedNav = .largeFiles
                    }
                    QuickAction(icon: "doc.on.doc.fill", title: "Duplicates") {
                        vm.selectedNav = .duplicates
                    }
                    QuickAction(icon: "trash.square.fill", title: "Uninstall") {
                        vm.selectedNav = .uninstaller
                    }
                    QuickAction(icon: "power.circle.fill", title: "Startup") {
                        vm.selectedNav = .startup
                    }
                    QuickAction(icon: "lock.shield.fill", title: "Shredder") {
                        vm.selectedNav = .shredder
                    }
                    QuickAction(icon: "wrench.and.screwdriver.fill", title: "Toolkit") {
                        vm.selectedNav = .toolkit
                    }
                }

                // System Info
                GlassCard {
                    HStack(spacing: 20) {
                        InfoPill(
                            icon: "desktopcomputer", label: "Model",
                            value: ToolkitService.shared.getMachineModel())
                        InfoPill(
                            icon: "applelogo", label: "macOS",
                            value: ToolkitService.shared.getMacOSVersion())
                        InfoPill(
                            icon: "clock", label: "Uptime",
                            value: ToolkitService.shared.getSystemUptime())
                        InfoPill(
                            icon: "cpu", label: "Cores",
                            value: "\(ProcessInfo.processInfo.processorCount)")
                        InfoPill(
                            icon: "memorychip", label: "Memory",
                            value: vm.memoryInfo?.formattedTotal ?? "N/A")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }
}

struct QuickAction: View {
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.brand)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .shadow(
                        color: .primary.opacity(isHovered ? 0.08 : 0.04),
                        radius: isHovered ? 8 : 4, y: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct InfoPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
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

// MARK: - Storage Overview Card (macOS System Settings style)

struct StorageOverviewCard: View {
    @Environment(AppViewModel.self) var vm
    @State private var expandedCategory: StorageCategory? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.brand)
                        Text("Storage")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Spacer()
                    Text(
                        "\(ByteCountFormatter.string(fromByteCount: vm.diskUsed, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: vm.diskTotal, countStyle: .file))"
                    )
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                }

                if vm.diskTotal > 0 {
                    // Multi-segment storage bar (like macOS Settings)
                    storageBar

                    // Expandable category cards
                    if !vm.storageCategories.isEmpty {
                        VStack(spacing: 2) {
                            ForEach(vm.storageCategories) { cat in
                                StorageCategoryRow(
                                    info: cat,
                                    diskTotal: vm.diskTotal,
                                    isExpanded: expandedCategory == cat.category,
                                    onToggle: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            expandedCategory = expandedCategory == cat.category ? nil : cat.category
                                        }
                                    }
                                )
                            }
                            // Free space row
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.primary.opacity(0.06))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.green.opacity(0.7))
                                }
                                Text("Available")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: vm.diskFree, countStyle: .file))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                // Empty space for alignment with arrows
                                Color.clear.frame(width: 16, height: 16)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    private var storageBar: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                if !vm.storageCategories.isEmpty {
                    ForEach(vm.storageCategories) { cat in
                        let pct = CGFloat(cat.size) / CGFloat(vm.diskTotal)
                        if pct > 0.005 {
                            let catColor = Color(
                                red: cat.category.color.r,
                                green: cat.category.color.g,
                                blue: cat.category.color.b)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(catColor)
                                .frame(width: max(3, geo.size.width * pct))
                                .help("\(cat.category.rawValue): \(cat.formattedSize)")
                        }
                    }
                }
                // Free space
                let freePct = CGFloat(vm.diskFree) / CGFloat(vm.diskTotal)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: max(3, geo.size.width * freePct))
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(height: 24)
    }
}

// MARK: - Storage Category Row (expandable)

private struct StorageCategoryRow: View {
    let info: StorageCategoryInfo
    let diskTotal: Int64
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    private var catColor: Color {
        Color(red: info.category.color.r, green: info.category.color.g, blue: info.category.color.b)
    }

    private var pct: Double {
        diskTotal > 0 ? Double(info.size) / Double(diskTotal) * 100 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(catColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: info.category.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(catColor)
                    }

                    // Name + percentage
                    VStack(alignment: .leading, spacing: 1) {
                        Text(info.category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                        Text(String(format: "%.1f%%", pct))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    // Size
                    Text(info.formattedSize)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(catColor)

                    // Expand arrow
                    if !info.subPaths.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, height: 16)
                    } else {
                        Color.clear.frame(width: 16, height: 16)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            // Expanded sub-paths
            if isExpanded && !info.subPaths.isEmpty {
                VStack(spacing: 0) {
                    ForEach(info.subPaths.indices, id: \.self) { idx in
                        let sub = info.subPaths[idx]
                        HStack(spacing: 8) {
                            Color.clear.frame(width: 28)
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(catColor.opacity(0.6))
                            Text(sub.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: sub.size, countStyle: .file))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                            Color.clear.frame(width: 16)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
