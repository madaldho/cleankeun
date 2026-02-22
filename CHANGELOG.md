# Changelog

All notable changes to Cleankeun will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-22

### Changed

- **Migrated to `@Observable` / `@Environment`** — Complete migration from `ObservableObject` + `@EnvironmentObject` + `@Published` to Swift Observation framework (`@Observable`, `@Environment(AppViewModel.self)`, `@Bindable`). Reduces overhead and enables granular view updates.
- **Timer replaced with structured concurrency** — System monitoring timer in AppViewModel now uses `Task` + `Task.sleep` instead of Foundation `Timer`, properly cancellable via `task.cancel()`.
- **`foregroundColor` → `foregroundStyle`** — Replaced all deprecated `foregroundColor()` calls across 8 view files (~30+ instances) with modern `foregroundStyle()`.
- **`cornerRadius` → `clipShape`** — Replaced all deprecated `.cornerRadius()` calls (~12 instances) with `.clipShape(RoundedRectangle(cornerRadius:))`.
- **`ScrollView(showsIndicators:)` → `.scrollIndicators(.hidden)`** — Replaced deprecated parameter across all 10 view files.
- **Hard-coded colors replaced with semantic tokens** — `Color.black.opacity()` → `Color.primary.opacity()`, `Color.gray.opacity()` → `.secondary.opacity()`, `Color.green` → `Theme.success` for correct light/dark mode behavior.
- **`DispatchQueue.main.async` → `Task { @MainActor in }`** — FileShredderView's drag-and-drop handler now uses Swift concurrency instead of GCD for main-thread dispatch.
- **`activate(ignoringOtherApps:)` → `activate()`** — Replaced deprecated NSApplication activation API in MenuBarView.
- **SystemMonitorService: removed `@MainActor`** — Service performs blocking I/O (Mach kernel calls, `getifaddrs`, FileManager) and is called from background Tasks; `@MainActor` was unnecessarily blocking the main thread.
- **DateFormatter optimization** — DuplicateFinderView's preview pane now uses a static `DateFormatter` instead of creating one on every view body evaluation.
- **ToolkitService documentation** — Added comprehensive doc comments explaining why `DispatchQueue.global().async` is used for subprocess execution (blocking `Process.run()` + `waitUntilExit()` would exhaust Swift concurrency thread pool).

### Added

- **Context menus** — Right-click context menus on list items in DuplicateFinderView (Reveal in Finder, Select All/Deselect All, Select All Except First), StartupManagerView (Reveal in Finder, Enable/Disable), and DiskUsageView (Reveal in Finder, Browse Directory).
- **Menu bar commands** — Application menu with Navigate (Cmd+1–0), Actions (Cmd+R scan, Cmd+Delete clean), and Help menus. Settings scene accessible via Cmd+,.
- **Keyboard shortcuts** — Full keyboard navigation across all 10 features.
- **`localizedStandardContains`** — App search now uses locale-aware string matching instead of `lowercased().contains()`.
- **Navigation title** — Detail view now sets `.navigationTitle()` for proper window title.
- **`GlassCard` / `SectionTitle` / `EmptyState` API cleanup** — `GlassCard` stores content directly (not as `@escaping` closure), `SectionTitle` and `EmptyState` gradient parameter now has default value.

## [1.1.5] - 2026-02-22

### Fixed

- **Trash detection broken** — `getTrashInfo()` and `emptyTrash()` now scan both `~/.Trash` (user trash) and `/Volumes/<name>/.Trashes/<uid>/` (external volume trashes). Previously only checked user trash, causing "Trash is empty" when items existed on external drives.
- **Large Files re-scans on every filter change** — Large Files now scans once (all files >= 1MB) and stores the full result set. Changing minimum size or file type filters instantly filters locally without rescanning. Auto-scans on first visit. Empty state message now differentiates "no files found" vs "no files match current filters".
- **Duplicate Finder missing image preview** — Preview pane now shows actual image thumbnails (via `NSImage(contentsOfFile:)`) for image files (jpg, png, gif, heic, etc.) instead of generic file icons. Non-image files still show the system file icon.
- **Startup Services missing app icons** — Startup items now show actual app bundle icons resolved via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`, with fallback to scanning `/Applications` for matching bundle IDs, and further fallback to extracting `.app` paths from `Program`/`ProgramArguments` in the plist. Falls back to generic icons only when no app bundle can be found.
- **Admin privilege tools silently failing** — Tools requiring root (Rebuild Spotlight, Free Purgeable Space) now prompt for administrator password via native macOS dialog using `osascript "do shell script ... with administrator privileges"`. Previously these would fail silently or show an unhelpful error. Startup service toggles for system plists (`/Library/LaunchDaemons`) also escalate via admin prompt instead of silently failing.

### Added

- **Cleaning progress animation** — Flash Clean now shows a full overlay during cleaning with animated sparkle icon, percentage counter, progress bar with gradient fill, "Freed X" live counter, and current filename display. `cleanItemsWithProgress()` reports per-item progress.

## [1.1.4] - 2026-02-22

### Added

- **Flash Clean individual item selection** — Each scanned junk item is now individually selectable/deselectable via click. Added per-category "Select All" / "Deselect All" buttons. Selected items show highlight background. Item limit per category increased from 40 to 50.
- **Hover states** — Added visual hover feedback to sidebar buttons, junk category rows, and other interactive elements across all views.

### Fixed

- **Button hit areas too small** — Comprehensive UX pass across all 12 views. Added `.contentShape(Rectangle())` to all interactive elements. Increased padding on buttons, checkboxes, filter chips, and action items. Specific improvements:
  - Sidebar buttons: padding increased to 9pt with hover state
  - Dashboard quick actions: vertical padding increased to 16pt
  - App Uninstaller: checkbox/chevron frames set to 28x28, filter buttons padded 10h/6v
  - Large Files: filter chips padded 12h/6v, checkbox/folder buttons 28-30px frames
  - Duplicate Finder: tab buttons padded 18h/10v, checkboxes 28x28
  - Disk Usage: back/home buttons now pill-shaped with branded background
  - File Shredder: add/clear/remove buttons all enlarged with proper hit areas
  - Toolkit: run button padded 20h/9v
  - Intro: start button sized 220x44 with capsule hit area
- **Non-selected sidebar text too dim** — Changed from `.secondary` to `.primary` for better readability.
- **Leftover sheet Done button** — Changed from `.plain` to `.glass` button style for consistency.

### Changed

- **DMG installer background redesigned** — Rich blue gradient with branded title, subtitle, decorative dot grid, prominent glowing arrow, and version badge. Much more visually striking than previous minimal dark design.
- GradientButton padding increased to 20h/10v for better touch targets

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
