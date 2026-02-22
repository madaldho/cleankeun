//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import AppKit
import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedNav: $vm.selectedNav)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            Group {
                switch vm.selectedNav {
                case .dashboard: DashboardView()
                case .junkCleaner: JunkCleanerView()
                case .uninstaller: AppUninstallerView()
                case .largeFiles: LargeFilesView()
                case .duplicates: DuplicateFinderView()
                case .memory: PerformanceView()
                case .startup: StartupManagerView()
                case .diskUsage: DiskUsageView()
                case .shredder: FileShredderView()
                case .toolkit: ToolkitView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaBar(edge: .bottom) {
                StatusBarView(message: vm.statusMessage, isScanning: vm.isScanning)
            }
        }
        .onAppear { vm.startMonitoring() }
        .onDisappear { vm.stopMonitoring() }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selectedNav: NavigationItem
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // App branding
            VStack(spacing: 6) {
                CleankeunLogo(size: 48)

                Text("Cleankeun")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Pro Edition")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary, in: .capsule)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 20)

            // Nav items
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(NavigationItem.allCases) { item in
                        SidebarButton(item: item, isSelected: selectedNav == item) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedNav = item
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

            Spacer()

            // Mini system stats
            VStack(spacing: 8) {
                if let mem = vm.memoryInfo {
                    MiniGauge(
                        label: "RAM", value: mem.usagePercentage / 100,
                        text: "\(Int(mem.usagePercentage))%",
                        color: mem.usagePercentage > 80 ? Theme.warning : Theme.brand)
                }
                if vm.diskTotal > 0 {
                    MiniGauge(
                        label: "Disk", value: Double(vm.diskUsed) / Double(vm.diskTotal),
                        text: ByteCountFormatter.string(
                            fromByteCount: vm.diskFree, countStyle: .file),
                        color: Double(vm.diskUsed) / Double(vm.diskTotal) > 0.85
                            ? Theme.danger : Theme.success)
                }
            }
            .padding(16)
        }
    }
}

struct SidebarButton: View {
    let item: NavigationItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : .secondary)
                    .frame(width: 22)

                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.navSelection)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MiniGauge: View {
    let label: String
    let value: Double
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * min(CGFloat(value), 1.0))
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 6)

            Text(text)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    let message: String
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isScanning {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
            } else {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(ToolkitService.shared.getMacOSVersion())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Reusable Components

struct GlassActionButton: View {
    let title: String
    let icon: String
    let role: ButtonRole?
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String, icon: String, role: ButtonRole? = nil,
        isLoading: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.role = role
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                } else {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
        }
        .buttonStyle(.glass)
        .disabled(isLoading)
    }
}

// Legacy GradientButton — now wraps GlassActionButton for compatibility
struct GradientButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String, icon: String, gradient: LinearGradient = Theme.blueGradient,
        isLoading: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        .tint(.white)
                } else {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct GlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            }
    }
}

struct AnimatedCircularGauge: View {
    let value: Double  // 0-1
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let size: CGFloat

    @State private var animatedValue: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedValue = min(value, 1.0)
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = min(newValue, 1.0)
            }
        }
    }
}

struct SectionTitle: View {
    let title: String
    let icon: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.brand)
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.brand.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.brand)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(50)
    }
}
