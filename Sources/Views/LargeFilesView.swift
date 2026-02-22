//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
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

                    // Filters
                    HStack(spacing: 8) {
                        Text("Min Size:")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        ForEach(
                            [(10, "10MB"), (50, "50MB"), (100, "100MB"), (500, "500MB")], id: \.0
                        ) { mb, label in
                            let size = Int64(mb) * 1024 * 1024
                            FilterChip(label: label, isActive: vm.largeFileMinSize == size) {
                                vm.largeFileMinSize = size
                            }
                        }

                        Divider().frame(height: 16)

                        Text("Type:")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        FilterChip(label: "All", isActive: vm.largeFileFilter == nil) {
                            vm.largeFileFilter = nil
                        }
                        ForEach([LargeFileType.video, .archive, .diskImage, .audio], id: \.self) {
                            ft in
                            FilterChip(label: ft.rawValue, isActive: vm.largeFileFilter == ft) {
                                vm.largeFileFilter = ft
                            }
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                    if vm.largeFiles.isEmpty && !vm.isScanning {
                        EmptyState(
                            icon: "doc.badge.arrow.up", title: "No Large Files",
                            subtitle: vm.allScannedLargeFiles.isEmpty
                                ? "Scan your Downloads, Desktop, Documents, Movies, Music, and Pictures for large files"
                                : "No files match the current filters. Try adjusting minimum size or file type.",
                            gradient: Theme.warningGradient)
                    } else {
                        ForEach(Array(vm.largeFiles.enumerated()), id: \.element.id) { _, file in
                            LargeFileCard(file: file) {
                                // BUG-26: Find by ID instead of stale index
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
                            "Move to Trash", icon: "trash",
                            gradient: selectedCount > 0
                                ? Theme.dangerGradient
                                : LinearGradient(
                                    colors: [.gray], startPoint: .leading, endPoint: .trailing)
                        ) {
                            showConfirm = true
                        }
                    }
                }
                .alert("Delete \(selectedCount) files?", isPresented: $showConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Move to Trash", role: .destructive) {
                        Task { await vm.deleteLargeFiles() }
                    }
                } message: {
                    Text(
                        "Free up \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)) by moving selected files to Trash"
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
                Text(file.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.head)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(file.formattedSize)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Text(file.fileType.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
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
                .shadow(
                    color: .primary.opacity(isHovered ? 0.07 : 0.04), radius: isHovered ? 6 : 3, y: 2
                )
        }
        .onHover { isHovered = $0 }
    }
}
