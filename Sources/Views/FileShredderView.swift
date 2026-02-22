//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileShredderView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showConfirm = false
    @State private var isDragOver = false
    @State private var shredPasses: Int = 3
    @State private var hasStarted = false

    var totalSize: Int64 {
        vm.shredItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        if !hasStarted {
            IntroView(
                title: "Shredder",
                description:
                    "File Shredder allows you to permanently delete files when no longer needed, it will overwrite the space once occupied by the deleted file. This means that even if a person or software tool knows exactly where to look for a deleted file, there is no longer any data to be found there.",
                bullets: [
                    "There are sensitive data you want to remove securely",
                    "There are locked items that can't be deleted in the normal way",
                ],
                icon: "scissors",
                gradient: Theme.dangerGradient,
                buttonTitle: "Select Files",
                onBack: nil,
                onStart: { hasStarted = true }
            )
        } else {
            shredderContent
        }
    }

    private var shredderContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        SectionTitle(
                            title: "File Shredder", icon: "lock.shield.fill",
                            gradient: Theme.dangerGradient)
                        Spacer()

                        // Passes selector
                        HStack(spacing: 6) {
                            Text("Passes:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $shredPasses) {
                                Text("1x").tag(1)
                                Text("3x").tag(3)
                                Text("7x").tag(7)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }

                        addFileButton
                    }

                    // Info banner
                    GlassCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.danger.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.dangerGradient)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Secure File Destruction")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(
                                    "Files are overwritten \(shredPasses)x with random data before deletion. Overwritten files cannot be recovered by any data recovery software."
                                )
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            }
                            Spacer()
                        }
                    }

                    // Drop zone
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isDragOver ? Theme.danger.opacity(0.6) : Color.secondary.opacity(0.25),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isDragOver ? Theme.danger.opacity(0.04) : Color.clear)
                            )

                        if vm.shredItems.isEmpty {
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.danger.opacity(0.1))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 26, weight: .light))
                                        .foregroundStyle(Theme.dangerGradient)
                                }
                                Text("Drop Files Here")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("or click the Add Files button above")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(vm.shredItems) { item in
                                    ShredItemRow(item: item) {
                                        // BUG-25: Remove by ID instead of stale index
                                        vm.shredItems.removeAll { $0.id == item.id }
                                    }
                                    if item.id != vm.shredItems.last?.id {
                                        Divider().padding(.horizontal, 16)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(minHeight: vm.shredItems.isEmpty ? 200 : nil)
                    .onDrop(of: [UTType.fileURL], isTargeted: $isDragOver) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                }
                .padding(28)
            }

            // Bottom action bar
            if !vm.shredItems.isEmpty {
                BottomBar {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                "\(vm.shredItems.count) item\(vm.shredItems.count == 1 ? "" : "s")"
                            )
                            .font(.system(size: 13, weight: .medium))
                            Text(
                                "Total: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))"
                            )
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Button {
                            vm.shredItems.removeAll()
                        } label: {
                            Text("Clear All")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)

                        GradientButton(
                            "Shred Now", icon: "flame.fill", gradient: Theme.dangerGradient,
                            isLoading: vm.isScanning
                        ) {
                            showConfirm = true
                        }
                    }
                }
                .alert("Confirm Secure Shred", isPresented: $showConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Shred", role: .destructive) {
                        Task { await vm.shredAllItems(passes: shredPasses) }
                    }
                } message: {
                    Text(
                        "Permanently destroy \(vm.shredItems.count) item(s)? This cannot be undone - files will be overwritten \(shredPasses)x with random data."
                    )
                }
            }
        }
    }

    private var addFileButton: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.prompt = "Add to Shredder"
            // Use async begin() instead of blocking runModal()
            panel.begin { response in
                if response == .OK {
                    for url in panel.urls {
                        vm.addShredItem(url: url)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text("Add Files")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Theme.brand)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.brand.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Use loadObject instead of deprecated loadItem(forTypeIdentifier:)
            provider.loadObject(ofClass: NSURL.self) { reading, _ in
                if let url = reading as? URL {
                    DispatchQueue.main.async {
                        vm.addShredItem(url: url)
                    }
                }
            }
        }
    }
}

struct ShredItemRow: View {
    let item: ShredItem
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(item.isDirectory ? Theme.brand.opacity(0.1) : Theme.warning.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(item.isDirectory ? Theme.brand : Theme.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                Text(item.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(isHovered ? 1.0 : 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onHover { isHovered = $0 }
    }
}
