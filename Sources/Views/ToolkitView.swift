//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct ToolkitView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var toolResults: [String: ToolResult] = [:]
    @State private var activeIntroTool: String? = nil

    var body: some View {
        if let tool = activeIntroTool, tool == "spotlight" {
            IntroView(
                title: "Reindex Spotlight",
                description:
                    "Spotlight allows you to quickly find any file, document, app, mail, and more. When the Spotlight search is not working correctly, rebuilding the Spotlight index can help you to resolve the issue.",
                bullets: [
                    "No results when searching your Mac",
                    "Experiencing odd behavior when using Spotlight",
                ],
                icon: "magnifyingglass",
                gradient: Theme.primaryGradient,
                buttonTitle: "Start",
                onBack: { activeIntroTool = nil },
                onStart: {
                    activeIntroTool = nil
                    Task {
                        await runTool("spotlight") {
                            await ToolkitService.shared.rebuildSpotlight()
                        }
                    }
                }
            )
        } else {
            toolkitContent
        }
    }

    private var toolkitContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                SectionTitle(
                    title: "Toolkit", icon: "wrench.and.screwdriver.fill",
                    gradient: Theme.primaryGradient)

                // System info card
                GlassCard {
                    HStack(spacing: 16) {
                        InfoChip(
                            icon: "desktopcomputer", label: "Model",
                            value: ToolkitService.shared.getMachineModel(),
                            color: Theme.brand)
                        InfoChip(
                            icon: "applelogo", label: "macOS",
                            value: ToolkitService.shared.getMacOSVersion(),
                            color: Theme.brandDark)
                        InfoChip(
                            icon: "clock", label: "Uptime",
                            value: ToolkitService.shared.getSystemUptime(),
                            color: Theme.warning)
                        InfoChip(
                            icon: "cpu", label: "Cores",
                            value: "\(ProcessInfo.processInfo.processorCount)",
                            color: Theme.brandLight)
                    }
                }

                // Tool cards grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16),
                    ], spacing: 16
                ) {
                    ToolCard(
                        icon: "network",
                        title: "Flush DNS Cache",
                        description:
                            "Clear the DNS resolver cache to fix network issues and apply DNS changes immediately.",
                        color: Theme.brand,
                        result: toolResults["dns"]
                    ) {
                        await runTool("dns") { await ToolkitService.shared.flushDNS() }
                    }

                    ToolCard(
                        icon: "magnifyingglass.circle.fill",
                        title: "Rebuild Spotlight",
                        description:
                            "Reindex Spotlight search to fix missing results or slow searches. May take several minutes.",
                        color: Theme.brandDark,
                        result: toolResults["spotlight"]
                    ) {
                        activeIntroTool = "spotlight"
                    }

                    ToolCard(
                        icon: "app.badge.checkmark",
                        title: "Rebuild Launch Services",
                        description:
                            "Fix duplicate 'Open With' entries and resolve file association problems.",
                        color: Theme.warning,
                        result: toolResults["launchservices"]
                    ) {
                        await runTool("launchservices") {
                            await ToolkitService.shared.rebuildLaunchServices()
                        }
                    }

                    ToolCard(
                        icon: "trash.circle.fill",
                        title: "Empty Trash",
                        description:
                            "Permanently remove all items from the Trash folder to free up disk space.",
                        color: Theme.danger,
                        result: toolResults["trash"]
                    ) {
                        await runTool("trash") { await ToolkitService.shared.emptyTrash() }
                    }

                    ToolCard(
                        icon: "internaldrive.fill",
                        title: "Free Purgeable Space",
                        description:
                            "Reclaim purgeable APFS disk space that macOS keeps as buffer for performance.",
                        color: Theme.success,
                        result: toolResults["purgeable"]
                    ) {
                        await runTool("purgeable") {
                            await ToolkitService.shared.freePurgeableSpace()
                        }
                    }

                    ToolCard(
                        icon: "memorychip.fill",
                        title: "Optimize Memory",
                        description:
                            "Free up inactive memory and compressed pages to improve system responsiveness.",
                        color: Theme.brand,
                        result: toolResults["memory"]
                    ) {
                        await runTool("memory") {
                            let result = await MemoryService.shared.optimizeMemory()
                            let freed = Int64(result.before.used) - Int64(result.after.used)
                            if freed > 0 {
                                return (
                                    true,
                                    "Freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .memory))"
                                )
                            }
                            return (true, "Memory optimized")
                        }
                    }
                }
            }
            .padding(28)
        }
    }

    private func runTool(
        _ key: String, action: @escaping () async -> (success: Bool, message: String)
    ) async {
        toolResults[key] = ToolResult(state: .running, message: "")
        let result = await action()
        toolResults[key] = ToolResult(
            state: result.success ? .success : .failed,
            message: result.message
        )
    }
}

// MARK: - Tool Result Model
struct ToolResult {
    enum State { case running, success, failed }
    let state: State
    let message: String
}

// MARK: - Tool Card
struct ToolCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let result: ToolResult?
    let action: () async -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if let result = result {
                        resultLabel(result)
                    }
                }
                Spacer()
            }

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button {
                    Task { await action() }
                } label: {
                    HStack(spacing: 5) {
                        if result?.state == .running {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                        }
                        Text("Run")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(color)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(result?.state == .running)
            }
        }
        .padding(16)
        .frame(minHeight: 170)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(
                    color: .primary.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 8 : 4, y: 2)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func resultLabel(_ result: ToolResult) -> some View {
        switch result.state {
        case .running:
            Text("Running...")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.warning)
        case .success:
            Text(result.message)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.success)
                .lineLimit(1)
        case .failed:
            Text(result.message)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.danger)
                .lineLimit(1)
        }
    }
}

// MARK: - Info Chip
struct InfoChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
