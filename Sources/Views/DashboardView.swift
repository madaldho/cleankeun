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

                // Storage Bar (Feature 7 — multi-segment)
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Storage")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(
                                "\(ByteCountFormatter.string(fromByteCount: vm.diskUsed, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: vm.diskTotal, countStyle: .file))"
                            )
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                        }

                        if vm.diskTotal > 0 {
                            // Multi-segment storage bar
                            if !vm.storageCategories.isEmpty {
                                GeometryReader { geo in
                                    HStack(spacing: 1) {
                                        ForEach(vm.storageCategories) { cat in
                                            let pct = CGFloat(cat.size) / CGFloat(vm.diskTotal)
                                            if pct > 0.005 {  // Only show segments > 0.5%
                                                let catColor = Color(
                                                    red: cat.category.color.r,
                                                    green: cat.category.color.g,
                                                    blue: cat.category.color.b)
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(catColor)
                                                    .frame(width: max(4, geo.size.width * pct))
                                            }
                                        }
                                        // Free space
                                        let freePct = CGFloat(vm.diskFree) / CGFloat(vm.diskTotal)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.primary.opacity(0.08))
                                            .frame(width: max(4, geo.size.width * freePct))
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .frame(height: 28)
                            } else {
                                // Fallback simple bar
                                GeometryReader { geo in
                                    let pct = CGFloat(vm.diskUsed) / CGFloat(vm.diskTotal)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.quaternary)
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                pct > 0.85
                                                    ? Theme.dangerGradient : Theme.primaryGradient
                                            )
                                            .frame(width: geo.size.width * pct)
                                            .animation(.easeInOut(duration: 0.8), value: pct)
                                    }
                                }
                                .frame(height: 28)
                            }

                            // Category legend
                            if !vm.storageCategories.isEmpty {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                                    ForEach(vm.storageCategories) { cat in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(
                                                    red: cat.category.color.r,
                                                    green: cat.category.color.g,
                                                    blue: cat.category.color.b))
                                                .frame(width: 8, height: 8)
                                            Text(cat.category.rawValue)
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                            Text(cat.formattedSize)
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.primary.opacity(0.15)).frame(width: 8, height: 8)
                                        Text("Free")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                        Text(ByteCountFormatter.string(fromByteCount: vm.diskFree, countStyle: .file))
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            } else {
                                HStack {
                                    HStack(spacing: 4) {
                                        Circle().fill(Theme.brand).frame(width: 8, height: 8)
                                        Text("Used").font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(.quaternary).frame(width: 8, height: 8)
                                        Text("Available").font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

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
