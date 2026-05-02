# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

Build and test via Xcode or `xcodebuild` CLI:
```bash
# Build
xcodebuild -project Chooser.xcodeproj -scheme Chooser -sdk iphonesimulator build

# Run unit tests
xcodebuild test -project Chooser.xcodeproj -scheme Chooser -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test
xcodebuild test -project Chooser.xcodeproj -scheme Chooser -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChooserTests/ChooserTests/<TestName>

# Run UI tests
xcodebuild test -project Chooser.xcodeproj -scheme Chooser -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ChooserUITests
```

## Architecture

SwiftUI + SwiftData app targeting iOS. Chooser is a fun, offline "random picker" app — users create custom lists and pick a random item via an animated roulette wheel or a simple random draw. No backend, no user accounts, no data collection.

- **`ChooserApp.swift`** — App entry point; configures the SwiftData `ModelContainer` with the `ChoiceList` schema and mounts the root `TabView` in a `WindowGroup`.
- **`RouletteView.swift`** — Main screen (tab 1); displays an animated spinning wheel populated with items from the currently selected list. Tap to spin, result highlighted on stop with haptic feedback and confetti animation.
- **`MyListsView.swift`** — List management screen (tab 2); shows all user-created lists with name and item count. Supports create, edit, delete. Tapping a list navigates to `ListDetailView` for inline item editing.
- **`ListDetailView.swift`** — Detail/edit view for a single list; quick-add items via text field + return key, swipe-to-delete, reorder via drag.
- **`SettingsView.swift`** — Settings screen (tab 3); toggles for sound, haptics, default draw mode (roulette vs. random list). Reset all data option.
- **`ChoiceList.swift`** — Primary data model; `@Model`-annotated with `name: String`, `items: [String]`, `createdAt: Date` properties for SwiftData persistence.

**Navigation**: `TabView` with 3 tabs (Roulette 🎰, Mes Listes 📋, Réglages ⚙️). `NavigationStack` within each tab. Push navigation from `MyListsView` → `ListDetailView`.

**Data flow**: SwiftData injects the `modelContext` via `.modelContainer()` on the scene. Views query lists with `@Query` and mutate via `modelContext.insert` / `modelContext.delete`. No network calls — everything is local.

**ViewModels**: MVVM pattern with `@Observable` classes (iOS 17+). One ViewModel per screen. No singletons — dependencies injected via SwiftUI environment.

**Tests**: Unit tests use Swift Testing (`@Test` / `#expect`); UI tests use XCTest + XCUIAutomation.

## Design Rules

- **Style**: Fun, colorful, playful — the app should feel satisfying to use.
- **Colors**: Primary `#FF6B6B` (coral), Secondary `#4ECDC4` (turquoise), Accent `#FFE66D` (sun yellow), Dark BG `#2C3E50`, Light BG `#F8F9FA`.
- **Font**: SF Pro Rounded (system). Use SF Symbols for icons.
- **Animations**: Spring animations, smooth wheel rotation, confetti on result. Generous but not heavy.
- **Haptics**: `UIImpactFeedbackGenerator` on spin launch and stop.
- **Dark mode**: Fully supported.
- **Empty states**: Engaging illustrations/messages when no lists exist or a list has no items.

## Code Rules

- SwiftUI only (no UIKit except for haptics).
- No force unwraps (`!`) — use `guard let` / `if let`.
- Code comments in English, variable/function names explicit.
- SwiftUI Preview for every view.
- Handle empty states gracefully — never show a blank screen.
- No networking code, no analytics, no auth, no in-app purchases.
