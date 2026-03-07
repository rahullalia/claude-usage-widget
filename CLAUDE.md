# CLAUDE.md — claudeUsageWidget

## Project Overview

A native macOS menu bar app (Swift + AppKit) that displays Claude.ai plan usage at a glance. Shows a circular ring progress indicator in the menu bar that fills up as usage climbs, with color-coded states. Click to expand a dropdown with full usage details.

**GitHub Repo:** `rahullalia/claude-usage-widget` (to be created)
**Distribution:** `.dmg` via GitHub Releases (built by GitHub Actions)
**Target:** macOS 13+ (Ventura and later)

---

## Folder Structure

```
claudeUsageWidget/
  ClaudeUsageWidget/         # Xcode project root
    AppDelegate.swift        # NSStatusItem, menu setup, app lifecycle
    UsageService.swift       # API fetching, polling timer, data models
    AuthManager.swift        # WKWebView login, persistent session, sign-out
    RingView.swift           # Core Graphics ring drawing (NSView subclass)
    MenuViewController.swift # Dropdown content (progress bars, labels)
    LoginWindowController.swift  # WKWebView login window
    Info.plist
    Assets.xcassets/
  ClaudeUsageWidget.xcodeproj/
  docs/
    plans/
      2026-03-07-menu-bar-widget-design.md   # Approved design doc
      2026-03-07-implementation-plan.md       # Step-by-step build plan
  .github/
    workflows/
      build.yml              # GitHub Actions: build + package .dmg on push to main
  README.md
  CLAUDE.md
```

---

## Key Architecture Decisions

- **AppKit only, no SwiftUI** — lighter weight, better NSStatusItem control
- **WKWebView with persistent data store** — `WKWebsiteDataStore.default()` keeps the user signed in across app restarts until they explicitly sign out
- **No Keychain needed** — persistent WebView data store handles session cookies natively
- **Core Graphics ring** — custom `NSView` draws the circular progress arc, no third-party libraries
- **5-minute polling** — `Timer.scheduledTimer` fetches usage data every 5 minutes; manual refresh also available

---

## Auth Flow

1. First launch: login window opens with WKWebView pointing to `claude.ai`
2. User logs in normally (supports 2FA, Google OAuth, etc.)
3. App detects successful login by observing URL redirect to `claude.ai` homepage
4. Session cookie persisted in `WKWebsiteDataStore.default()` — survives app restarts
5. Sign Out: calls `WKWebsiteDataStore.default().removeData(...)` to wipe session

---

## API

The claude.ai usage endpoint is identified by inspecting network requests on `claude.ai/settings/usage` during development. Auth is the persistent WKWebView session cookie — no manual token handling.

Expected data shape:
```swift
struct UsageData {
    let currentSession: UsageStat      // percentUsed, resetsInMinutes
    let weeklyAllModels: UsageStat     // percentUsed, resetsAt (Date)
    let weeklySonnetOnly: UsageStat    // percentUsed, resetsAt (Date)
}
```

---

## Ring Color States

| Usage % | Color |
|---------|-------|
| 0–59% | Monochrome (adapts to light/dark menu bar) |
| 60–84% | Amber (#F59E0B) |
| 85–100% | Red (#EF4444) |

Ring always shows the **highest usage % across all three metrics**.

---

## Distribution

- GitHub Actions builds a `.dmg` on every push to `main`
- `.dmg` is attached to a GitHub Release
- Users: download `.dmg`, drag to Applications, open — done
- First-time macOS Gatekeeper prompt: "Open Anyway" in System Settings (expected for unsigned apps)
- Future: Apple Developer Program code signing to remove Gatekeeper prompt

---

## Commands

```bash
# Open in Xcode
open ClaudeUsageWidget.xcodeproj

# Build from CLI
xcodebuild -scheme ClaudeUsageWidget -configuration Release

# Create DMG (after build)
create-dmg ...   # see docs/plans/implementation-plan.md
```

---

## Status

- [ ] Design approved
- [ ] Implementation plan written
- [ ] Xcode project scaffolded
- [ ] Auth (WKWebView login + persistent session)
- [ ] API endpoint identified + UsageService built
- [ ] Ring drawing (Core Graphics)
- [ ] Dropdown menu UI
- [ ] Color state logic
- [ ] GitHub Actions build pipeline
- [ ] GitHub repo created + first release

---

## Last Updated

2026-03-07
