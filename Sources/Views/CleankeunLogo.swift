//
//  Cleankeun Pro — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

// MARK: - Logo View
struct CleankeunLogo: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Theme.primaryGradient)
                .shadow(color: Theme.brand.opacity(0.35), radius: size * 0.15, y: size * 0.08)

            // Dynamic Shapes
            ZStack {
                // Sweep / clean arc
                Circle()
                    .trim(from: 0.2, to: 0.9)
                    .stroke(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-45))
                    .frame(width: size * 0.6, height: size * 0.6)

                // Sparkles
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: -size * 0.15, y: -size * 0.15)

                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .offset(x: size * 0.2, y: size * 0.1)
            }
        }
        .frame(width: size, height: size)
    }
}
