# Cleankeun Pro

A native macOS system cleaner and optimizer built with Swift and SwiftUI, featuring Apple's Liquid Glass design language.

![macOS](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

| Feature | Description |
|---|---|
| **Dashboard** | Real-time system overview — CPU, RAM, disk, and network at a glance |
| **Flash Clean** | Remove system junk, caches, logs, and temporary files |
| **App Uninstaller** | Complete app removal including library, support, and preference files |
| **Large Files** | Find large files consuming disk space |
| **Duplicate Finder** | Detect identical files across common directories |
| **Performance** | Memory optimization with detailed RAM/CPU breakdown and pressure graph |
| **Startup Items** | Manage login items and Launch Agents/Daemons |
| **Disk Analyzer** | Visual disk usage breakdown with folder-by-folder navigation |
| **File Shredder** | Secure file destruction with 1x/3x/7x overwrite passes |
| **Toolkit** | Flush DNS, Rebuild Spotlight, Rebuild Launch Services, Empty Trash, Free Purgeable Space, Optimize Memory |

Plus a **Menu Bar widget** for real-time monitoring and quick actions without opening the full app.

## Screenshots

*Coming soon*

## Requirements

- **macOS 26** (Tahoe) or later
- **Xcode 26** with Swift 6.2
- Apple Silicon or Intel Mac

## Build

```bash
# Clone the repository
git clone https://github.com/madaldho/cleankeun.git
cd cleankeun

# Build (debug)
swift build

# Build (release)
swift build -c release

# Run
swift run
```

## Create DMG Installer

```bash
chmod +x build-dmg.sh
./build-dmg.sh
```

The DMG will be created at `dist/Cleankeun.dmg` with a drag-to-Applications installer.

## Project Structure

```
Sources/
├── CleankeunApp.swift          # App entry point + MenuBarExtra
├── Models/
│   └── Models.swift            # All data models
├── Services/
│   ├── SystemMonitorService    # CPU, RAM, disk, network monitoring
│   ├── MemoryService           # Memory optimization
│   ├── JunkCleanerService      # System junk scanning/cleaning
│   ├── AppUninstallerService   # App detection and removal
│   ├── LargeFileScannerService # Large file discovery
│   ├── DuplicateFinderService  # Duplicate file detection
│   ├── StartupManagerService   # Login items and launch agents
│   ├── DiskUsageService        # Disk usage analysis
│   ├── FileShredderService     # Secure file shredding
│   └── ToolkitService          # System maintenance utilities
├── ViewModels/
│   └── AppViewModel.swift      # Main app state management
└── Views/
    ├── AppTheme.swift           # Brand colors and design tokens
    ├── ContentView.swift        # Main layout + NavigationSplitView
    ├── DashboardView.swift      # System overview dashboard
    ├── JunkCleanerView.swift    # Flash Clean interface
    ├── AppUninstallerView.swift # App uninstaller interface
    ├── LargeFilesView.swift     # Large file manager
    ├── DuplicateFinderView.swift # Duplicate finder interface
    ├── MemoryView.swift         # Performance/memory view
    ├── StartupManagerView.swift # Startup items manager
    ├── DiskUsageView.swift      # Disk analyzer
    ├── FileShredderView.swift   # File shredder interface
    ├── ToolkitView.swift        # System toolkit
    ├── MenuBarView.swift        # Menu bar widget
    ├── IntroView.swift          # Feature intro screens
    └── CleankeunLogo.swift      # App logo component
```

## Design

Cleankeun uses Apple's **Liquid Glass** design language introduced in macOS 26:

- System materials (`.regularMaterial`, `.ultraThinMaterial`) for translucent surfaces
- `.glass` and `.glassProminent` button styles
- `GlassEffectContainer` for grouped glass elements
- `.safeAreaBar()` for scroll-aware bottom bars
- Adaptive colors that work seamlessly in both light and dark mode

The brand identity uses a focused 3-color blue palette with semantic colors for danger (red), success (green), and warning (orange).

## Tech Stack

- **Language:** Swift 6.2 (language mode v5)
- **UI Framework:** SwiftUI
- **Build System:** Swift Package Manager
- **Platform:** macOS 26+ (Apple Silicon + Intel)
- **Dependencies:** None — fully self-contained

## Author

**Muhamad Ali Ridho** ([@madaldho](https://github.com/madaldho))

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
