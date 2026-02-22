//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct PerformanceView: View {
    @Environment(AppViewModel.self) var vm
    @State private var hasStarted = false

    var body: some View {
        if !hasStarted {
            IntroView(
                title: "Free Up RAM",
                description:
                    "RAM is temporary data storage that your Mac uses to execute programs and process applications. When there's not enough RAM, you can experience system slowdown or other issues.",
                bullets: [
                    "Experiencing Performance issues",
                    "Lag when typing",
                    "Taking too long to load apps or web pages",
                ],
                icon: "memorychip",
                gradient: Theme.primaryGradient,
                buttonTitle: "Start",
                onBack: nil,
                onStart: { hasStarted = true }
            )
        } else {
            performanceContent
        }
    }

    private var performanceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    SectionTitle(title: "Performance", icon: "cpu", gradient: Theme.primaryGradient)
                    Spacer()
                    GradientButton(
                        "Optimize RAM", icon: "bolt.fill", gradient: Theme.primaryGradient,
                        isLoading: vm.isScanning
                    ) {
                        Task { await vm.optimizeMemory() }
                    }
                }

                // Big gauges
                HStack(spacing: 20) {
                    if let mem = vm.memoryInfo {
                        GlassCard {
                            VStack(spacing: 16) {
                                AnimatedCircularGauge(
                                    value: mem.usagePercentage / 100, lineWidth: 14,
                                    gradient: mem.usagePercentage > 80
                                        ? Theme.dangerGradient : Theme.successGradient, size: 130
                                )
                                .overlay {
                                    VStack(spacing: 2) {
                                        Text("\(Int(mem.usagePercentage))%")
                                            .font(
                                                .system(size: 28, weight: .bold, design: .rounded))
                                        Text("Memory")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Memory breakdown
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible()), count: 4),
                                    spacing: 12
                                ) {
                                    MemChip(label: "Active", value: fmt(mem.active), color: Theme.brand)
                                    MemChip(label: "Wired", value: fmt(mem.wired), color: Theme.danger)
                                    MemChip(
                                        label: "Compressed", value: fmt(mem.compressed),
                                        color: Theme.brandDark)
                                    MemChip(label: "Free", value: fmt(mem.free), color: Theme.success)
                                }

                                // Pressure bar
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Memory Pressure")
                                        .font(.system(size: 11, weight: .semibold))
                                    GeometryReader { geo in
                                        HStack(spacing: 0) {
                                            Rectangle().fill(Theme.brand.opacity(0.7))
                                                .frame(
                                                    width: geo.size.width * CGFloat(mem.active)
                                                        / CGFloat(mem.total))
                                            Rectangle().fill(Theme.danger.opacity(0.7))
                                                .frame(
                                                    width: geo.size.width * CGFloat(mem.wired)
                                                        / CGFloat(mem.total))
                                            Rectangle().fill(Theme.brandDark.opacity(0.7))
                                                .frame(
                                                    width: geo.size.width * CGFloat(mem.compressed)
                                                        / CGFloat(mem.total))
                                            Rectangle().fill(Theme.success.opacity(0.2))
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .frame(height: 12)

                                    HStack(spacing: 14) {
                                        PressureLegend(color: Theme.brand, label: "Active")
                                        PressureLegend(color: Theme.danger, label: "Wired")
                                        PressureLegend(color: Theme.brandDark, label: "Compressed")
                                        PressureLegend(color: Theme.success.opacity(0.4), label: "Free")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // CPU
                    GlassCard {
                        VStack(spacing: 16) {
                            AnimatedCircularGauge(
                                value: (vm.cpuInfo?.usagePercentage ?? 0) / 100, lineWidth: 14,
                                gradient: Theme.primaryGradient, size: 130
                            )
                            .overlay {
                                VStack(spacing: 2) {
                                    Text("\(Int(vm.cpuInfo?.usagePercentage ?? 0))%")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                    Text("CPU")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible()), count: 3),
                                spacing: 12
                            ) {
                                MemChip(
                                    label: "User",
                                    value: "\(Int(vm.cpuInfo?.userPercentage ?? 0))%", color: Theme.brand)
                                MemChip(
                                    label: "System",
                                    value: "\(Int(vm.cpuInfo?.systemPercentage ?? 0))%",
                                    color: Theme.warning)
                                MemChip(
                                    label: "Idle",
                                    value: "\(Int(vm.cpuInfo?.idlePercentage ?? 100))%",
                                    color: Theme.success)
                            }

                            VStack(spacing: 6) {
                                HStack {
                                    Text("Processor Cores").font(
                                        .system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text("\(vm.cpuInfo?.coreCount ?? 0)").font(
                                        .system(size: 11, weight: .bold, design: .rounded))
                                }
                                HStack {
                                    Text("Uptime").font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text(ToolkitService.shared.getSystemUptime())
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Network
                GlassCard {
                    HStack(spacing: 24) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Theme.success.opacity(0.12)).frame(
                                    width: 36, height: 36)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16)).foregroundStyle(Theme.success)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Download").font(.system(size: 10)).foregroundStyle(
                                    .secondary)
                                Text(vm.networkInfo?.formattedDownload ?? "0 B/s")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                        }
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Theme.warning.opacity(0.12)).frame(
                                    width: 36, height: 36)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16)).foregroundStyle(Theme.warning)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upload").font(.system(size: 10)).foregroundStyle(.secondary)
                                Text(vm.networkInfo?.formattedUpload ?? "0 B/s")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
    }

    func fmt(_ val: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(val), countStyle: .memory)
    }
}

struct MemChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(
                color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PressureLegend: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}
