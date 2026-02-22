//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct JunkCleanerView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        SectionTitle(
                            title: "Flash Clean", icon: "bolt.circle.fill",
                            gradient: Theme.primaryGradient)
                        Spacer()
                        GradientButton(
                            "Scan", icon: "magnifyingglass", gradient: Theme.primaryGradient,
                            isLoading: vm.isScanning
                        ) {
                            Task { await vm.scanJunk() }
                        }
                    }

                    if vm.junkItems.isEmpty && !vm.isScanning {
                        EmptyState(
                            icon: "sparkles", title: "System Looks Clean",
                            subtitle:
                                "Click Scan to find junk files, caches, logs, and temporary files on your Mac",
                            gradient: Theme.primaryGradient)
                    } else if !vm.junkItems.isEmpty {
                        // Summary
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(vm.junkItems.count) files found")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(
                                        "Total: \(ByteCountFormatter.string(fromByteCount: vm.totalJunkSize, countStyle: .file))"
                                    )
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 12) {
                                    Text(
                                        "Selected: \(ByteCountFormatter.string(fromByteCount: vm.selectedJunkSize, countStyle: .file))"
                                    )
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.brand)

                                    Button("All") { vm.toggleAllJunk(selected: true) }
                                        .buttonStyle(.plain).font(
                                            .system(size: 11, weight: .medium)
                                        ).foregroundStyle(Theme.brand)
                                    Button("None") { vm.toggleAllJunk(selected: false) }
                                        .buttonStyle(.plain).font(
                                            .system(size: 11, weight: .medium)
                                        ).foregroundStyle(Theme.brand)
                                }
                            }
                        }

                        // Category cards
                        ForEach(JunkCategory.allCases) { cat in
                            if let items = vm.junkByCategory[cat], !items.isEmpty {
                                JunkCategoryRow(
                                    category: cat, items: items,
                                    onToggle: { sel in
                                        vm.toggleJunkCategory(cat, selected: sel)
                                    })
                            }
                        }
                    }
                }
                .padding(28)
            }

            if !vm.junkItems.isEmpty {
                BottomBar {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vm.selectedJunkCount) items selected")
                                .font(.system(size: 13, weight: .medium))
                            Text(
                                ByteCountFormatter.string(
                                    fromByteCount: vm.selectedJunkSize, countStyle: .file)
                            )
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        GradientButton(
                            "Clean", icon: "trash",
                            gradient: vm.selectedJunkCount > 0
                                ? Theme.dangerGradient
                                : LinearGradient(
                                    colors: [.gray], startPoint: .leading, endPoint: .trailing),
                            isLoading: vm.isScanning
                        ) {
                            showConfirm = true
                        }
                    }
                }
                .alert("Confirm Cleanup", isPresented: $showConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clean", role: .destructive) { Task { await vm.cleanJunk() } }
                } message: {
                    Text(
                        "Permanently delete \(vm.selectedJunkCount) files (\(ByteCountFormatter.string(fromByteCount: vm.selectedJunkSize, countStyle: .file)))?"
                    )
                }
            }
        }
    }
}

struct JunkCategoryRow: View {
    let category: JunkCategory
    let items: [JunkItem]
    let onToggle: (Bool) -> Void
    @State private var isExpanded = false

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    private var selectedCount: Int { items.filter(\.isSelected).count }
    private var catColor: Color {
        Color(red: category.color.r, green: category.color.g, blue: category.color.b)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.brand.opacity(0.1))
                            .frame(width: 34, height: 34)
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.brand)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("\(items.count) files")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.brand)

                    // Mini progress
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 2)
                        Circle().trim(
                            from: 0,
                            to: items.isEmpty ? 0 : Double(selectedCount) / Double(items.count)
                        )
                        .stroke(Theme.brand, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 18, height: 18)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                VStack(spacing: 0) {
                    ForEach(items.prefix(40)) { item in
                        HStack(spacing: 8) {
                            Image(
                                systemName: item.isSelected
                                    ? "checkmark.circle.fill" : "circle"
                            )
                            .foregroundStyle(
                                item.isSelected ? Theme.brand : Color.gray.opacity(0.4))
                            .font(.system(size: 13))
                            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                                .resizable()
                                .frame(width: 14, height: 14)
                            Text(item.fileName)
                                .font(.system(size: 11))
                                .lineLimit(1).truncationMode(.middle)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 3)
                    }
                    if items.count > 40 {
                        Text("+ \(items.count - 40) more")
                            .font(.system(size: 10)).foregroundStyle(.secondary).padding(6)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).shadow(
                color: .black.opacity(0.05), radius: 6, y: 2)
        }
    }
}

struct BottomBar<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
    }
}
