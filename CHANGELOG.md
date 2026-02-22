# Changelog

All notable changes to Cleankeun will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.3] - 2026-02-22

### Fixed

- **SystemMonitorService data race** — Added `@MainActor` isolation to prevent concurrent access to `prevCPUInfo` and `prevNetworkBytes` mutable state
- **StartupManagerView inverted toggle** — Warning dialog now correctly appears when disabling a service (was previously triggered when enabling)
- **DiskUsageView body side-effect** — Removed `SystemMonitorService.shared.getDiskInfo()` call from view body; now uses cached values from ViewModel with `.onAppear` refresh
- **FileShredderView deprecated APIs** — Replaced blocking `NSOpenPanel.runModal()` with async `panel.begin()`; replaced deprecated `loadItem(forTypeIdentifier:)` with `loadObject(ofClass:)`

### Added

- **Support Developer** — Saweria link (`saweria.co/madaldho`) added to landing page (prominent section with animated coffee icon), README (badge), and app sidebar footer (subtle link)

### Changed

- Landing page nav bar now includes "Support" anchor link
- Landing page footer now includes Saweria support link

## [1.1.2] - 2026-02-22

### Fixed

- **DMG installer now professional** — Uses `create-dmg` with custom dark background, proper icon layout (app on left, Applications on right), volume icon, and Finder-stored `.DS_Store` layout. Drag-to-install works like professional macOS apps.
- **App properly registers** — App installs to `/Applications` as a proper `.app` bundle and registers with Launch Services (`com.cleankeun.pro`).
- **Menu bar icon** — Changed to `sparkles` SF Symbol for consistency with app icon theme.
- **Consistent app icon** — Generated via compiled Swift matching `CleankeunLogo.swift` design (blue gradient + sweep arc + sparkles).

### Changed

- Build script completely rewritten with 7-step pipeline: compile → bundle → icon → DMG background → sign → create-dmg → verify
- DMG now includes background image with arrow and "Drag to Applications to install" text
- DMG volume has custom icon matching the app icon
- Removed PyObjC dependency; all generation done via compiled Swift

## [1.1.1] - 2026-02-22

### Fixed

- **App "rusak" / cannot open** — App was not properly code-signed after bundle assembly; Gatekeeper rejected it because resources were added after the linker signature. Now the build script performs a full `codesign --force --deep` ad-hoc signing with entitlements after all resources are in place.
- **Inconsistent app icon** — Replaced the old PyObjC-generated icon (broom/dots) with a new compiled Swift icon generator that matches the `CleankeunLogo.swift` design (blue gradient + sweep arc + sparkles). Dock icon, Finder icon, and in-app logo are now visually consistent.
- **Menu bar icon** — Changed from `bubbles.and.sparkles.fill` to `sparkles` SF Symbol to better match the app's sparkle theme.

### Changed

- Build script now uses compiled Swift for icon generation instead of PyObjC (which was unavailable)
- Build script creates proper entitlements and seals all resources into the code signature
- Version bumped to 1.1.1

## [1.1.0] - 2026-02-22

### Fixed

- **Window activation** — App now properly activates on launch and when clicking the Dock icon (added `NSApplicationDelegateAdaptor` with `CleankeunAppDelegate`)
- **Monitoring timer race** — Changed to reference-counted timer so multiple views can independently start/stop monitoring without conflicts
- **Menu bar "Open Cleankeun"** — Uses `canBecomeMain` for reliable window lookup instead of fragile title matching
- **Menu bar lifecycle** — Properly stops monitoring on disappear to balance the start call
- **App Uninstaller crash** — Replaced index-based `ForEach` with identity-based iteration to prevent out-of-bounds crashes during filtering
- **Alert force unwrap** — Replaced `appToUninstall!.name` with safe optional map
- **Status message clearing** — Clean/delete operations now preserve result messages across subsequent scans
- **Pipe deadlock** — `ToolkitService.runProcess()` reads stderr before `waitUntilExit()` to prevent hanging
- **Cached system info** — `ToolkitService` uses lazy vars for macOS version and machine model to avoid repeated syscalls

### Changed

- **Landing page redesigned** — Premium dark-themed GitHub Pages site with animated ambient orbs, scroll-reveal animations, trust bar, feature cards, and responsive layout
- Build script version bumped to 1.1.0 with icon preservation across rebuilds

## [1.0.0] - 2026-02-22

### Added

- **Dashboard** - Real-time system overview with CPU, RAM, disk, and network monitoring
- **Flash Clean** - Scan and remove system junk, caches, logs, and temporary files
- **App Uninstaller** - Complete app removal including related library/support files
- **Large Files** - Find and manage large files consuming disk space
- **Duplicate Finder** - Detect identical files across Downloads, Desktop, Documents, and Pictures
- **Performance** - Memory optimization with detailed RAM and CPU breakdown
- **Startup Items** - Manage login items and startup services (Launch Agents/Daemons)
- **Disk Analyzer** - Visual disk usage breakdown with folder navigation
- **File Shredder** - Secure file destruction with multi-pass overwrite (1x/3x/7x)
- **Toolkit** - System maintenance utilities (Flush DNS, Rebuild Spotlight, Rebuild Launch Services, Empty Trash, Free Purgeable Space, Optimize Memory)
- **Menu Bar Extra** - Real-time system monitoring widget with quick actions
- **Liquid Glass UI** - Native macOS 26 Liquid Glass design language with adaptive light/dark mode
- **Blue brand identity** - Consistent 3-color blue palette across the entire app
- **DMG installer** - Build script for creating distributable `.dmg` package
