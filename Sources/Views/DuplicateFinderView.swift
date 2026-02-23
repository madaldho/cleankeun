//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

enum DuplicateFilter: String, CaseIterable, Identifiable {
    case all = "All Items"
    case folders = "Folders"
    case audio = "Audio"
    case video = "Video"
    case image = "Image"
    case document = "Documents"
    case archive = "Package"
    case other = "Other"
    case similar = "Similar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .folders: return "folder.fill"
        case .audio: return "music.note"
        case .video: return "film.fill"
        case .image: return "photo.fill"
        case .document: return "doc.text.fill"
        case .archive: return "doc.zipper"
        case .other: return "doc.fill"
        case .similar: return "sparkles.square.filled.on.square"
        }
    }

    func matches(type: LargeFileType) -> Bool {
        switch self {
        case .all: return true
        case .folders, .similar: return false // No native mapping in current model yet
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
    @State private var showScopeSettings = false
    @State private var selectedGroupId: UUID? = nil
    @State private var selectedFileIdForPreview: UUID? = nil

    private static let previewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var selectedCount: Int { vm.duplicateGroups.flatMap(\.files).filter(\.isSelected).count }
    var selectedSize: Int64 {
        vm.duplicateGroups.flatMap(\.files).filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var filteredGroups: [DuplicateGroup] {
        var groups = vm.duplicateGroups.filter { selectedFilter.matches(type: $0.fileType) }
        groups.sort { $0.wastedSpace > $1.wastedSpace }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()

            if vm.isScanningDuplicates {
                scanningState
            } else if vm.duplicateGroups.isEmpty {
                emptyState
            } else {
                tabBar
                Divider()

                HStack(spacing: 0) {
                    leftSidebar
                    Divider()
                    rightDetailPane
                }
                Divider()
                bottomBar
            }
        }
        .onChange(of: filteredGroups.count) { _, _ in
            if selectedGroupId == nil {
                selectedGroupId = filteredGroups.first?.id
            }
        }
        .onAppear {
            if selectedGroupId == nil {
                selectedGroupId = filteredGroups.first?.id
            }
        }
    }

    // MARK: - Scanning State
    private var scanningState: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning for duplicates...")
                .font(.system(size: 18, weight: .bold))
            Text("This might take a moment depending on the folders selected.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            Button {
                Task {
                    selectedGroupId = nil
                    await vm.scanDuplicates()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Start Over")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Duplicates")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Button {
                showScopeSettings.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .accessibilityLabel("Filter Options")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showScopeSettings, arrowEdge: .bottom) {
                scanScopePopover
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @MainActor
    private var scanScopePopover: some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 12) {
            Text("Scan Locations")
                .font(.system(size: 13, weight: .semibold))

            let home = NSHomeDirectory()
            let folders: [(name: String, path: String, icon: String)] = [
                ("Downloads", "\(home)/Downloads", "arrow.down.circle"),
                ("Desktop", "\(home)/Desktop", "menubar.dock.rectangle"),
                ("Documents", "\(home)/Documents", "doc.fill"),
                ("Pictures", "\(home)/Pictures", "photo.fill"),
                ("Movies", "\(home)/Movies", "film"),
                ("Music", "\(home)/Music", "music.note"),
            ]

            ForEach(folders, id: \.path) { folder in
                HStack(spacing: 8) {
                    Image(systemName: folder.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.brand)
                        .frame(width: 16)
                    Toggle(folder.name, isOn: Binding(
                        get: { vm.duplicateScanPaths[folder.path] ?? true },
                        set: { vm.duplicateScanPaths[folder.path] = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                }
            }

            Divider()

            Toggle("Include hidden files", isOn: $vm.duplicateScanHidden)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 220)
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(DuplicateFilter.allCases) { filter in
                    let isActive = selectedFilter == filter
                    Button {
                        selectedFilter = filter
                        selectedGroupId = filteredGroups.first?.id
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11))
                            Text(filter.rawValue)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No Duplicates Scanned")
                .font(.system(size: 18, weight: .bold))
            Text("Scan Downloads, Desktop, Documents, Pictures, Movies, and Music for identical files")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button("Scan Now") {
                Task { await vm.scanDuplicates() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        VStack(spacing: 0) {
            // Auto Select Bar
            HStack {
                Menu {
                    Button("Smart Select (Keep First)") { vm.smartSelectDuplicates() }
                    Button("Deselect All") { vm.deselectAllDuplicates() }
                    Divider()
                    Button("Select All") {
                        for gi in vm.duplicateGroups.indices {
                            for fi in vm.duplicateGroups[gi].files.indices {
                                vm.duplicateGroups[gi].files[fi].isSelected = true
                            }
                        }
                    }
                } label: {
                    Text("Auto Select")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.brand)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if filteredGroups.isEmpty {
                Text("No items match this category.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredGroups) { group in
                            DuplicateGroupSidebarRow(
                                group: group,
                                isSelected: selectedGroupId == group.id,
                                onSelect: { selectedGroupId = group.id },
                                onToggleFile: { fileId in toggleFile(group.id, fileId) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Right Detail Pane
    private var rightDetailPane: some View {
        VStack(spacing: 0) {
            if let group = vm.duplicateGroups.first(where: { $0.id == selectedGroupId }) {
                VSplitView {
                    Table(group.files, selection: $selectedFileIdForPreview) {
                        TableColumn("Name") { file in
                            HStack(spacing: 8) {
                                Button {
                                    toggleFile(group.id, file.id)
                                } label: {
                                    Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(file.isSelected ? Theme.brand : .secondary.opacity(0.5))
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                                
                                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                
                                Text(file.fileName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .contextMenu {
                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                                }
                            }
                        }
                        TableColumn("Size") { file in
                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                .foregroundStyle(.secondary)
                        }
                        TableColumn("Last Modified") { file in
                            Text(Self.previewDateFormatter.string(from: file.modificationDate))
                                .foregroundStyle(.secondary)
                        }
                        TableColumn("Path") { file in
                            Text(file.directory.components(separatedBy: "/").dropFirst().joined(separator: " ▹ "))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                                .help(file.directory)
                        }
                    }
                    .frame(minHeight: 150)
                    
                    if let fileToPreview = group.files.first(where: { $0.id == (selectedFileIdForPreview ?? group.files.first?.id) }) {
                        filePreviewPane(for: fileToPreview)
                            .frame(height: 250)
                    }
                }
            } else {
                Text("Select a group to view details")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .onChange(of: selectedGroupId) { _, _ in
            selectedFileIdForPreview = nil
        }
    }

    @ViewBuilder
    private func filePreviewPane(for file: DuplicateFile) -> some View {
        VStack(spacing: 12) {
            Spacer()
            
            // Image Preview if image
            FilePreviewImage(filePath: file.path)
                .frame(maxHeight: 160)
                .cornerRadius(8)
                .shadow(radius: 2)
            
            Text(file.fileName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            }
            Button("Open File") {
                NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
            }
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                    .font(.system(size: 24, weight: .regular))
                Text("Selected")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 24)
            
            Button {
                showConfirm = true
            } label: {
                Text("Remove")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 36)
                    .background(selectedCount > 0 ? Theme.brand : Color.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Permanently delete \(selectedCount) duplicates?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) { Task { await vm.deleteDuplicates() } }
        } message: {
            Text("Permanently delete selected duplicates (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))? This cannot be undone.")
        }
    }

    private func toggleFile(_ groupId: UUID, _ fileId: UUID) {
        if let gi = vm.duplicateGroups.firstIndex(where: { $0.id == groupId }),
           let fi = vm.duplicateGroups[gi].files.firstIndex(where: { $0.id == fileId }) {
            vm.duplicateGroups[gi].files[fi].isSelected.toggle()
        }
    }
}

// MARK: - Duplicate Group Sidebar Row
struct DuplicateGroupSidebarRow: View {
    let group: DuplicateGroup
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFile: (UUID) -> Void
    
    @State private var isExpanded = false
    @State private var isHovered = false

    var selectedCount: Int { group.files.filter(\.isSelected).count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Image(systemName: group.fileType.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : Theme.brand)
                
                Text(group.files.first?.fileName ?? "Unknown Group")
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer(minLength: 8)
                
                Text("\(selectedCount) | \(group.files.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                
                Text(group.formattedSize)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.brand : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .padding(.horizontal, 8)
            .onHover { isHovered = $0 }
            .onTapGesture {
                onSelect()
            }
            
            if isExpanded {
                ForEach(group.files) { file in
                    HStack(spacing: 8) {
                        Button {
                            onToggleFile(file.id)
                        } label: {
                            Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(file.isSelected ? Theme.brand : .secondary.opacity(0.5))
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        
                        Text(file.directory.components(separatedBy: "/").last ?? file.directory)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.leading, 42)
                    .padding(.trailing, 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect()
                    }
                }
            }
        }
    }
}
