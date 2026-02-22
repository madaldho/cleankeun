//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme
// Clean 3-color blue brand palette with proper light/dark mode support.
// Core colors: Brand Blue, Soft Sky, Slate (+ semantic: red for danger, green for success)
struct Theme {
    // ── Brand Core Colors ──────────────────────────────────────────────
    // Primary brand blue — used for accents, selection, primary actions
    static let brand = Color(hex: "1A8CFF")          // Vibrant blue
    static let brandLight = Color(hex: "4DA8FF")      // Lighter tint for gradients
    static let brandDark = Color(hex: "0066CC")        // Deeper blue for pressed states

    // ── Semantic Colors ────────────────────────────────────────────────
    static let danger = Color.red
    static let success = Color.green
    static let warning = Color.orange

    // ── Adaptive Surface Colors (work in both light & dark mode) ──────
    // Use .primary/.secondary from SwiftUI for text — they auto-adapt.
    // For subtle text, use .secondary directly instead of custom opacity.
    static let subtle = Color.secondary
    static let separator = Color(nsColor: .separatorColor)

    // Card backgrounds — use system materials instead of manual opacity
    static let cardBg = Color(nsColor: .controlBackgroundColor).opacity(0.5)
    static let surfaceBg = Color(nsColor: .windowBackgroundColor).opacity(0.3)

    // Navigation selection
    static let navSelection = brand

    // ── Brand Gradient (the ONE primary gradient) ──────────────────────
    static let primaryGradient = LinearGradient(
        colors: [brand, brandLight], startPoint: .topLeading, endPoint: .bottomTrailing)

    // ── Functional Gradients (only for specific semantic uses) ─────────
    // Danger actions (delete, shred, uninstall)
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "E53E3E"), Color(hex: "F56565")], startPoint: .topLeading,
        endPoint: .bottomTrailing)

    // Success / healthy state
    static let successGradient = LinearGradient(
        colors: [Color(hex: "38A169"), Color(hex: "68D391")], startPoint: .topLeading,
        endPoint: .bottomTrailing)

    // Warning / caution
    static let warningGradient = LinearGradient(
        colors: [Color(hex: "DD6B20"), Color(hex: "F6AD55")], startPoint: .topLeading,
        endPoint: .bottomTrailing)

    // ── Legacy Compatibility Aliases ───────────────────────────────────
    // All old gradient names map to the 3-color system
    static let blueGradient = primaryGradient
    static let cyanGradient = primaryGradient
    static let secondaryGradient = primaryGradient
    static let purpleGradient = primaryGradient
    static let greenGradient = successGradient
    static let orangeGradient = warningGradient
    static let redGradient = dangerGradient
}
