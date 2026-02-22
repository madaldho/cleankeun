//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

enum DuplicateFilter: String, CaseIterable, Identifiable {
    case all = "All Items"
    case audio = "Audio"
    case video = "Video"
    case image = "Image"
    case document = "Documents"
    case archive = "Package"
    case other = "Other"

    var id: String { rawValue }

    func matches(type: LargeFileType) -> Bool {
        switch self {
        case .all: return true
        case .audio: return type == .audio
        case .video: return type == .video
        case .image: return type == .image
        case .document: return type == .document
        case .archive: return type == .archive || type == .diskImage
        case .other: return type == .other
        }
    }
}

struct DuplicateFinderView: View {
    @Environment(AppViewModel.self) var vm
    @State private var showConfirm = false
    @State private var selectedFilter: DuplicateFilter = .all
    @State private var previewFile: DuplicateFile? = nil
    @State private var previewGroup: DuplicateGroup? = nil

    // H4: Static DateFormatter — avoid recreating inside body
    private static let previewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()

    var selectedCount: Int { vm.duplicateGroups.flatMap(\.files).filter(\.isSelected).count }
    var selectedSize: Int64 {
        vm.duplicateGroups.flatMap(\.files).filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var filteredGroups: [DuplicateGroup] {
        vm.duplicateGroups.filter { selectedFilter.matches(type: $0.fileType) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if vm.duplicateGroups.isEmpty && !vm.isScanning {
                Spacer()
                EmptyState(
                    icon: "doc.on.doc",
                    title: "No Duplicates",
                    subtitle:
                        "Scan Downloads, Desktop, Documents, and Pictures for identical files"
                )
                Spacer()
            } else {
                tabNavigation
                Divider()
                mainArea
            }

            if !vm.duplicateGroups.isEmpty {
                bottomBar
            }
        }
    }

    // MARK: - Subviews
    private var headerView: some View {
        HStack {
            SectionTitle(
                title: "Duplicates", icon: "doc.on.doc.fill", gradient: Theme.primaryGradient)
            Spacer()
            GradientButton(
                "Scan", icon: "magnifyingglass", gradient: Theme.primaryGradient,
                isLoading: vm.isScanning
            ) {
                Task {
                    previewFile = nil
                    previewGroup = nil
                    await vm.scanDuplicates()
                }
            }
        }
        .padding(28)
        .padding(.bottom, -10)
    }

    private var tabNavigation: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(DuplicateFilter.allCases) { filter in
                    Button {
                        withAnimation { selectedFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(
                                .system(
                                    size: 13,
                                    weight: selectedFilter == filter ? .semibold : .regular)
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                selectedFilter == filter ? Theme.brand.opacity(0.15) : Color.clear
                            )
                            .foregroundStyle(
                                selectedFilter == filter
                                    ? Theme.brand : .secondary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 12)
    }

    private var mainArea: some View {
        HStack(spacing: 0) {
            // Left List
            ScrollView {
                VStack(spacing: 0) {
                    if filteredGroups.isEmpty {
                        Text("No items match this category.")
                            .foregroundStyle(.secondary)
                            .padding(40)
                    }

                    ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { _, group in
                        DuplicateGroupRow(
                            group: group,
                            previewFile: $previewFile,
                            previewGroup: $previewGroup,
                            onToggle: { fileId in
                                if let gi = vm.duplicateGroups.firstIndex(where: {
                                    $0.id == group.id
                                }),
                                    let fi = vm.duplicateGroups[gi].files.firstIndex(where: {
                                        $0.id == fileId
                                    })
                                {
                                    vm.duplicateGroups[gi].files[fi].isSelected.toggle()
                                }
                            }
                        )
                        // C3: Context menu on duplicate group
                        .contextMenu {
                            Button {
                                if let first = group.files.first {
                                    NSWorkspace.shared.selectFile(first.path, inFileViewerRootedAtPath: "")
                                }
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                            Divider()
                            Button {
                                if let gi = vm.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                                    for fi in vm.duplicateGroups[gi].files.indices {
                                        vm.duplicateGroups[gi].files[fi].isSelected = true
                                    }
                                }
                            } label: {
                                Label("Select All in Group", systemImage: "checkmark.circle")
                            }
                            Button {
                                if let gi = vm.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                                    for fi in vm.duplicateGroups[gi].files.indices {
                                        vm.duplicateGroups[gi].files[fi].isSelected = false
                                    }
                                }
                            } label: {
                                Label("Deselect All in Group", systemImage: "circle")
                            }
                            Divider()
                            Button {
                                if let gi = vm.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                                    // Select all except the first (keep original)
                                    for fi in vm.duplicateGroups[gi].files.indices {
                                        vm.duplicateGroups[gi].files[fi].isSelected = fi > 0
                                    }
                                }
                            } label: {
                                Label("Select All Except First", systemImage: "checkmark.circle.badge.xmark")
                            }
                        }
                        Divider().padding(.leading, 32)
                    }
                }
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)

            Divider()

            // Right Preview Pane
            previewPane
                .frame(width: 320)
                .background(.ultraThinMaterial)
        }
    }

    private var bottomBar: some View {
        BottomBar {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("\(selectedCount)").font(.system(size: 18, weight: .semibold))
                            Text("Byte\nSelected").font(.system(size: 9)).foregroundStyle(
                                .secondary)
                        }
                        Divider().frame(height: 20)
                        HStack(spacing: 4) {
                            Text(
                                selectedSize > 0
                                    ? ByteCountFormatter.string(
                                        fromByteCount: selectedSize, countStyle: .file
                                    ).replacingOccurrences(of: " MB", with: "")
                                        .replacingOccurrences(of: " GB", with: "") : "0"
                            ).font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("Total\nSelected").font(.system(size: 9)).foregroundStyle(
                                .secondary)
                        }
                    }
                }
                Spacer()
                GradientButton(
                    "Remove", icon: "trash",
                    gradient: selectedCount > 0
                        ? Theme.dangerGradient
                        : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                ) {
                    showConfirm = true
                }
                .disabled(selectedCount == 0)
            }
        }
        .alert("Remove \(selectedCount) duplicates?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) { Task { await vm.deleteDuplicates() } }
        }
    }

    private var previewPane: some View {
        VStack {
            if let file = previewFile {
                VStack(spacing: 30) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                            .shadow(color: .primary.opacity(0.1), radius: 10, y: 5)
                            .frame(width: 140, height: 180)

                        // Show actual image thumbnail for image files, otherwise file icon
                        if LargeFileType.detect(from: file.path) == .image,
                           let nsImage = NSImage(contentsOfFile: file.path) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 130, height: 170)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            VStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)

                                Text(
                                    file.path.components(separatedBy: ".").last?.uppercased() ?? "FILE"
                                )
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 16) {
                        previewRow(label: "Name:", value: file.fileName)
                        previewRow(
                            label: "Size:",
                            value: ByteCountFormatter.string(
                                fromByteCount: file.size, countStyle: .file))
                        previewRow(label: "Path:", value: file.directory)

                        if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                            let date = attrs[.modificationDate] as? Date
                        {
                            // H4: Use static DateFormatter instead of creating inside body
                            let dateStr = Self.previewDateFormatter.string(from: date)
                            previewRow(label: "Last Modified:", value: dateStr)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("Select an item to preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func previewRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Duplicate Group Row
struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    @Binding var previewFile: DuplicateFile?
    @Binding var previewGroup: DuplicateGroup?
    let onToggle: (UUID) -> Void

    @State private var isExpanded = false

    private var typeColor: Color {
        Color(
            red: group.fileType.color.r, green: group.fileType.color.g, blue: group.fileType.color.b
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Parent Header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6).fill(typeColor.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: group.fileType.icon)
                            .font(.system(size: 10)).foregroundStyle(typeColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.files.first?.fileName ?? "Unknown Group")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("\(group.formattedSize)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    let selectedCount = group.files.filter({ $0.isSelected }).count
                    Text("\(selectedCount) | \(group.files.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Children
            if isExpanded {
                ForEach(group.files) { file in
                    HStack(spacing: 10) {
                        // Checkbox
                        Button {
                            onToggle(file.id)
                        } label: {
                            Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(
                                    file.isSelected
                                        ? Theme.brand
                                        : .secondary.opacity(0.4)
                                )
                                .font(.system(size: 14))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // File info button (sets preview)
                        Button {
                            previewFile = file
                            previewGroup = group
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                                    .resizable()
                                    .frame(width: 16, height: 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.directory)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                    Text(
                                        ByteCountFormatter.string(
                                            fromByteCount: file.size, countStyle: .file)
                                    )
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                previewFile?.id == file.id
                                    ? Color.primary.opacity(0.06) : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    // C3: Context menu on individual duplicate file
                    .contextMenu {
                        Button {
                            NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        Button {
                            onToggle(file.id)
                        } label: {
                            Label(file.isSelected ? "Deselect" : "Select", systemImage: file.isSelected ? "circle" : "checkmark.circle")
                        }
                    }
                    .padding(.leading, 42)
                    .padding(.trailing, 16)
                    .padding(.vertical, 2)
                }
                .padding(.bottom, 8)
            }
        }
    }
}
