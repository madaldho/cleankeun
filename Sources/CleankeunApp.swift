//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import AppKit
import SwiftUI

@main
struct CleankeunApp: App {
    @NSApplicationDelegateAdaptor(CleankeunAppDelegate.self) private var appDelegate
    @State private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .frame(minWidth: 960, minHeight: 640)
                .onAppear {
                    // Ensure the app shows in the Dock and can receive focus
                    NSApplication.shared.setActivationPolicy(.regular)
                }
        }
        .defaultSize(width: 1080, height: 720)
        // C1: Menu bar commands with keyboard shortcuts (C2)
        .commands {
            // Replace default Edit menu
            CommandGroup(replacing: .textEditing) { }

            // Navigation shortcuts (Cmd+1 through Cmd+0)
            CommandMenu("Navigate") {
                ForEach(Array(NavigationItem.allCases.enumerated()), id: \.element) { index, item in
                    Button(item.rawValue) {
                        vm.selectedNav = item
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index == 9 ? 0 : index + 1)")), modifiers: .command)
                }
            }

            // Actions menu
            CommandMenu("Actions") {
                Button("Scan") {
                    Task { await performScanForCurrentView() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Clean / Delete") {
                    // Posts notification for current view to handle
                    NotificationCenter.default.post(name: .cleankeunPerformClean, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Divider()

                Button("Select All Items") {
                    NotificationCenter.default.post(name: .cleankeunSelectAll, object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Button("Deselect All Items") {
                    NotificationCenter.default.post(name: .cleankeunDeselectAll, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Link("Cleankeun Website", destination: URL(string: "https://madaldho.github.io/cleankeun/")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/madaldho/cleankeun/issues")!)
                Divider()
                Link("Support Developer", destination: URL(string: "https://saweria.co/madaldho")!)
            }
        }

        // M7: Settings scene (Cmd+, support)
        Settings {
            CleankeunSettingsView()
                .environment(vm)
        }

        MenuBarExtra("Cleankeun", systemImage: "sparkles") {
            MenuBarView()
                .environment(vm)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func performScanForCurrentView() async {
        switch vm.selectedNav {
        case .dashboard: vm.refreshSystemInfo()
        case .junkCleaner: await vm.scanJunk()
        case .uninstaller: await vm.scanApps()
        case .largeFiles: await vm.scanLargeFiles()
        case .duplicates: await vm.scanDuplicates()
        case .memory: await vm.optimizeMemory()
        case .startup: vm.scanStartupItems()
        case .diskUsage: await vm.analyzeDiskUsage()
        case .shredder: break // No scan action
        case .toolkit: break // No scan action
        }
    }
}

// MARK: - Notification Names for keyboard commands
extension Notification.Name {
    static let cleankeunPerformClean = Notification.Name("cleankeunPerformClean")
    static let cleankeunSelectAll = Notification.Name("cleankeunSelectAll")
    static let cleankeunDeselectAll = Notification.Name("cleankeunDeselectAll")
}

// MARK: - Settings View (M7)
struct CleankeunSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            CleankeunLogo(size: 64)
            Text("Cleankeun Pro")
                .font(.title2.bold())
            Text("macOS System Cleaner & Optimizer")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label("Version 1.2.0", systemImage: "info.circle")
                Label("by Muhamad Ali Ridho", systemImage: "person")
                Link(destination: URL(string: "https://github.com/madaldho/cleankeun")!) {
                    Label("GitHub Repository", systemImage: "link")
                }
                Link(destination: URL(string: "https://saweria.co/madaldho")!) {
                    Label("Support Developer", systemImage: "cup.and.saucer.fill")
                }
            }
            .font(.callout)
        }
        .padding(30)
        .frame(width: 320)
    }
}

// MARK: - App Delegate
// Handles reopen (Dock click) and ensures the main window comes to front properly.
class CleankeunAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    break
                }
            }
        }
        // L2: Use modern activate API
        NSApplication.shared.activate()
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate()
    }
}
