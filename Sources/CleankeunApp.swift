//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

@main
struct CleankeunApp: App {
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra("Cleankeun", systemImage: "bubbles.and.sparkles.fill") {
            MenuBarView()
                .environmentObject(vm)
        }
        .menuBarExtraStyle(.window)
    }
}
