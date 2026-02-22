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
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 960, minHeight: 640)
                .onAppear {
                    // Ensure the app shows in the Dock and can receive focus
                    NSApplication.shared.setActivationPolicy(.regular)
                }
        }
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra("Cleankeun", systemImage: "sparkles") {
            MenuBarView()
                .environmentObject(vm)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate
// Handles reopen (Dock click) and ensures the main window comes to front properly.
class CleankeunAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Re-open the main window when user clicks the Dock icon and no window is visible
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    break
                }
            }
        }
        // Always bring app to front
        sender.activate(ignoringOtherApps: true)
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app is in the foreground on launch
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
