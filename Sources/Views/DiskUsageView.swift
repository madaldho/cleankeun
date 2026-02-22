//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct DiskUsageView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    SectionTitle(title: "Disk Analyzer", icon: "chart.pie.fill", gradient: Theme.primaryGradient)
                    Spacer()
                    GradientButton("Analyze", icon: "magnifyingglass", gradient: Theme.primaryGradient, isLoading: vm.isScanning) {
                        Task { await vm.analyzeDiskUsage() }
                    }
                }

                // Breadcrumb
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(vm.currentDiskPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                    Spacer()
                    if vm.currentDiskPath != NSHomeDirectory() {
                        Button {
                            let parent = (vm.currentDiskPath as NSString).deletingLastPathComponent
                            Task { await vm.navigateDiskUsage(to: parent) }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left").font(.system(size: 9))
                                Text("Back").font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(Theme.brand)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        Task { await vm.navigateDiskUsage(to: NSHomeDirectory()) }
                    } label: {
                        Text("Home").font(.system(size: 10, weight: .medium)).foregroundColor(Theme.brand)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))

                // Disk overview bar
                let disk = SystemMonitorService.shared.getDiskInfo()
                if disk.total > 0 {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Disk Overview").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(ByteCountFormatter.string(fromByteCount: disk.free, countStyle: .file)) available")
                                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.primaryGradient)
                                        .frame(width: geo.size.width * CGFloat(disk.used) / CGFloat(disk.total))
                                }
                            }
                            .frame(height: 22)
                        }
                    }
                }

                if vm.diskUsageItems.isEmpty && !vm.isScanning {
                    EmptyState(icon: "chart.pie", title: "No Data", subtitle: "Click Analyze to see disk usage breakdown for each folder", gradient: Theme.primaryGradient)
                } else {
                    // BUG-29: Guard against maxSize being 0
                    let maxSize = max(vm.diskUsageItems.first?.size ?? 1, 1)
                    ForEach(vm.diskUsageItems.prefix(35)) { item in
                        DiskRow(item: item, maxSize: maxSize) {
                            if item.isDirectory {
                                Task { await vm.navigateDiskUsage(to: item.path) }
                            }
                        }
                    }
                    if vm.diskUsageItems.count > 35 {
                        Text("+ \(vm.diskUsageItems.count - 35) more items")
                            .font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 8)
                    }
                }
            }
            .padding(28)
        }
    }
}

struct DiskRow: View {
    let item: DiskUsageItem
    let maxSize: Int64
    let onNavigate: () -> Void
    @State private var isHovered = false

    private var barColor: LinearGradient {
        item.isDirectory ? Theme.primaryGradient : Theme.warningGradient
    }

    var body: some View {
        Button(action: onNavigate) {
            HStack(spacing: 10) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isDirectory ? Theme.primaryGradient : Theme.warningGradient)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.system(size: 12, weight: item.isDirectory ? .semibold : .regular))
                            .foregroundStyle(.primary).lineLimit(1)
                        Spacer()
                        Text(item.formattedSize)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if item.isDirectory {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor.opacity(0.5))
                                .frame(width: max(2, geo.size.width * CGFloat(item.size) / CGFloat(maxSize)))
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(.regularMaterial)
                .shadow(color: .primary.opacity(isHovered ? 0.06 : 0.03), radius: isHovered ? 5 : 2, y: 1)
        )
        .onHover { isHovered = $0 }
    }
}
