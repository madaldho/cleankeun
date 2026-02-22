//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct LargeFilesView: View {
    @Environment(AppViewModel.self) var vm
    @State private var showConfirm = false

    var selectedCount: Int { vm.largeFiles.filter(\.isSelected).count }
    var selectedSize: Int64 { vm.largeFiles.filter(\.isSelected).reduce(0) { $0 + $1.size } }

    var body: some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        SectionTitle(
                            title: "Large Files", icon: "arrow.up.doc.fill",
                            gradient: Theme.warningGradient)
                        Spacer()
                        GradientButton(
                            "Scan", icon: "magnifyingglass", gradient: Theme.primaryGradient,
                            isLoading: vm.isScanning
                        ) {
                            Task { await vm.scanLargeFiles() }
                        }
                    }

                    // File Type Tabs (like BuhoCleaner)
                    ScrollView(.horizontal) {
                        HStack(spacing: 2) {
                            FileTypeTab(label: "All Files", icon: "doc.fill", isActive: vm.largeFileFilter == nil) {
                                vm.largeFileFilter = nil
                            }
                            ForEach(LargeFileType.allCases) { ft in
                                FileTypeTab(
                                    label: ft.rawValue, icon: ft.icon,
                                    isActive: vm.largeFileFilter == ft
                                ) {
                                    vm.largeFileFilter = ft
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    // Filters & Sort Row
                    HStack(spacing: 12) {
                        // Min Size Filter
                        HStack(spacing: 6) {
                            Text("Min:")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            ForEach(
                                [(10, "10MB"), (50, "50MB"), (100, "100MB"), (500, "500MB")], id: \.0
                            ) { mb, label in
                                let size = Int64(mb) * 1024 * 1024
                                FilterChip(label: label, isActive: vm.largeFileMinSize == size) {
                                    vm.largeFileMinSize = size
                                }
                            }
                        }

                        Spacer()

                        // Sort options
                        HStack(spacing: 6) {
                            Text("Sort:")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            ForEach(LargeFileSortOption.allCases) { opt in
                                FilterChip(label: opt.rawValue, isActive: vm.largeFileSortBy == opt) {
                                    if vm.largeFileSortBy == opt {
                                        vm.largeFileSortAscending.toggle()
                                    } else {
                                        vm.largeFileSortBy = opt
                                        vm.largeFileSortAscending = false
                                    }
                                }
                            }

                            // Sort direction
                            Button {
                                vm.largeFileSortAscending.toggle()
                            } label: {
                                Image(systemName: vm.largeFileSortAscending ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.brand)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                                    .contentShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))

                    // Results count
                    if !vm.largeFiles.isEmpty {
                        HStack {
                            Text("\(vm.largeFiles.count) files")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            let total = vm.largeFiles.reduce(0) { $0 + $1.size }
                            Text("Total: \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.brand)
                        }
                    }

                    if vm.largeFiles.isEmpty && !vm.isScanning {
                        EmptyState(
                            icon: "doc.badge.arrow.up", title: "No Large Files",
                            subtitle: vm.allScannedLargeFiles.isEmpty
                                ? "Scan your Downloads, Desktop, Documents, Movies, Music, and Pictures for large files"
                                : "No files match the current filters. Try adjusting minimum size or file type.",
                            gradient: Theme.warningGradient)
                    } else {
                        ForEach(vm.largeFiles) { file in
                            LargeFileCard(file: file) {
                                if let idx = vm.largeFiles.firstIndex(where: { $0.id == file.id }) {
                                    vm.largeFiles[idx].isSelected.toggle()
                                }
                            }
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                                }
                                Button("Open") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                                }
                                Divider()
                                Button(file.isSelected ? "Deselect" : "Select") {
                                    if let idx = vm.largeFiles.firstIndex(where: { $0.id == file.id }) {
                                        vm.largeFiles[idx].isSelected.toggle()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(28)
            }
            .scrollIndicators(.hidden)

            if !vm.largeFiles.isEmpty {
                BottomBar {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(selectedCount) selected")
                                .font(.system(size: 13, weight: .medium))
                            Text(
                                ByteCountFormatter.string(
                                    fromByteCount: selectedSize, countStyle: .file)
                            )
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        GradientButton(
                            "Delete Permanently", icon: "trash",
                            gradient: selectedCount > 0
                                ? Theme.dangerGradient
                                : LinearGradient(
                                    colors: [.gray], startPoint: .leading, endPoint: .trailing)
                        ) {
                            showConfirm = true
                        }
                        .disabled(selectedCount == 0)
                    }
                }
                .alert("Permanently delete \(selectedCount) files?", isPresented: $showConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete Permanently", role: .destructive) {
                        Task { await vm.deleteLargeFiles() }
                    }
                } message: {
                    Text(
                        "Permanently delete selected files (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))? This cannot be undone."
                    )
                }
            }
        }
        .onAppear {
            if vm.allScannedLargeFiles.isEmpty && !vm.isScanning {
                Task { await vm.scanLargeFiles() }
            }
        }
    }
}

// MARK: - File Type Tab (BuhoCleaner-style)
struct FileTypeTab: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? Theme.brand : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? Theme.brand.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .primary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    isActive
                        ? AnyShapeStyle(Theme.primaryGradient)
                        : AnyShapeStyle(.secondary.opacity(0.12))
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct LargeFileCard: View {
    let file: LargeFile
    let onToggle: () -> Void
    @State private var isHovered = false

    // H4: static date formatter
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: file.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(file.isSelected ? Theme.brand : .secondary.opacity(0.35))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                .resizable()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(file.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.head)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(file.formattedSize)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
                HStack(spacing: 4) {
                    Text(file.fileType.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Text(Self.dateFormatter.string(from: file.modificationDate))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            Button {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.regularMaterial)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .shadow(
                    color: .primary.opacity(isHovered ? 0.07 : 0.04), radius: isHovered ? 6 : 3, y: 2
                )
        }
        .onHover { isHovered = $0 }
    }
}
