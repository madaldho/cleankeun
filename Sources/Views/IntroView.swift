//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import SwiftUI

struct IntroView: View {
    let title: String
    let description: String
    let bullets: [String]
    let icon: String
    let gradient: LinearGradient
    let buttonTitle: String
    let onBack: (() -> Void)?
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                if let onBack = onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Back")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    .padding(.leading, 20)
                }
                Spacer()
            }

            Spacer()

            // Header
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(width: 600)
            }
            .padding(.bottom, 60)

            // Content
            HStack(alignment: .top, spacing: 60) {
                // Bullets
                VStack(alignment: .leading, spacing: 16) {
                    Text("Use this tool if:")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.bottom, 4)

                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .center, spacing: 8) {
                            Circle()
                                .fill(.tertiary)
                                .frame(width: 4, height: 4)
                            Text(bullet)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Big Native Icon
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.brand)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .padding(.bottom, 80)

            // Start Button
            Button(action: onStart) {
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 220, height: 44)
                    .background(Theme.primaryGradient, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
