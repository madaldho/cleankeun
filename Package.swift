// swift-tools-version: 6.2
//
//  Cleankeun — macOS System Cleaner & Optimizer
//  Copyright (c) 2025-2026 Muhamad Ali Ridho. All rights reserved.
//  Licensed under the MIT License. See LICENSE file for details.
//

import PackageDescription

let package = Package(
    name: "Cleankeun",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Cleankeun",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
