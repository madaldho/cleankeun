//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct JunkCleanerView: View {
    @Environment(AppViewModel.self) var vm
    @State private var showConfirm = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
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
                                            .buttonStyle(.plain)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Theme.brand)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Theme.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                                            .contentShape(Rectangle())
                                        Button("None") { vm.toggleAllJunk(selected: false) }
                                            .buttonStyle(.plain)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Theme.brand)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Theme.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                                            .contentShape(Rectangle())
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
                                        },
                                        onToggleItem: { item in
                                            vm.toggleJunkItem(item)
                                        })
                                }
                            }
                        }
                    }
                    .padding(28)
                }
                .scrollIndicators(.hidden)

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

            // Cleaning progress overlay
            if vm.isCleaning {
                CleaningProgressOverlay(
                    progress: vm.cleaningProgress,
                    currentFile: vm.cleaningCurrentFile,
                    freedSoFar: vm.cleaningFreedSoFar
                )
            }
        }
    }
}

// MARK: - Cleaning Progress Overlay
struct CleaningProgressOverlay: View {
    let progress: Double
    let currentFile: String
    let freedSoFar: Int64

    @State private var animatedProgress: Double = 0
    @State private var sparkleRotation: Double = 0

    var body: some View {
        ZStack {
            Color.primary.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated sparkle icon
                ZStack {
                    Circle()
                        .fill(Theme.brand.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Theme.brand.opacity(0.08))
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .rotationEffect(.degrees(sparkleRotation))
                }

                VStack(spacing: 8) {
                    Text("Cleaning in Progress")
                        .font(.system(size: 18, weight: .bold))
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                }

                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.1))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.primaryGradient)
                                .frame(width: geo.size.width * animatedProgress)
                        }
                    }
                    .frame(height: 12)
                    .frame(maxWidth: 300)

                    if freedSoFar > 0 {
                        Text("Freed \(ByteCountFormatter.string(fromByteCount: freedSoFar, countStyle: .file))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.brand)
                    }
                }

                // Current file
                if !currentFile.isEmpty {
                    Text(currentFile)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 300)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .primary.opacity(0.3), radius: 30, y: 10)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

struct JunkCategoryRow: View {
    let category: JunkCategory
    let items: [JunkItem]
    let onToggle: (Bool) -> Void
    let onToggleItem: (JunkItem) -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    private var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    private var selectedCount: Int { items.filter(\.isSelected).count }
    private var catColor: Color {
        Color(red: category.color.r, green: category.color.g, blue: category.color.b)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.brand.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Image(systemName: category.icon)
                            .font(.system(size: 15))
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

                    // Selection indicator
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 2)
                        Circle().trim(
                            from: 0,
                            to: items.isEmpty ? 0 : Double(selectedCount) / Double(items.count)
                        )
                        .stroke(Theme.brand, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 20, height: 20)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)

                // Select All / None row
                HStack {
                    Spacer()
                    Button("Select All") { onToggle(true) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    Text("|").foregroundStyle(.quaternary).font(.system(size: 11))
                    Button("Deselect All") { onToggle(false) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                VStack(spacing: 0) {
                    ForEach(items.prefix(50)) { item in
                        Button {
                            onToggleItem(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(
                                    systemName: item.isSelected
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .foregroundStyle(
                                    item.isSelected ? Theme.brand : .secondary.opacity(0.4))
                                .font(.system(size: 14))

                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                                    .resizable()
                                    .frame(width: 16, height: 16)

                                Text(item.fileName)
                                    .font(.system(size: 11))
                                    .lineLimit(1).truncationMode(.middle)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(item.formattedSize)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .background(
                                item.isSelected
                                    ? Theme.brand.opacity(0.04)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            }
                            Button(item.isSelected ? "Deselect" : "Select") {
                                onToggleItem(item)
                            }
                        }
                    }
                    if items.count > 50 {
                        Text("+ \(items.count - 50) more files")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).shadow(
                color: .primary.opacity(isHovered ? 0.08 : 0.05), radius: isHovered ? 8 : 6, y: 2)
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
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
