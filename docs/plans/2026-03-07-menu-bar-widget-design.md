# Design Doc: Claude Usage Widget — macOS Menu Bar App

**Date:** 2026-03-07
**Status:** Approved
**Author:** Rahul Lalia

---

## Problem

Claude.ai shows plan usage limits (current session %, weekly %, reset timers) at `claude.ai/settings/usage`, but there's no way to see this at a glance without opening a browser tab. Checking usage mid-session breaks flow.

---

## Goal

A lightweight native macOS menu bar app that shows Claude usage status at a glance, accessible from the menu bar at any time without switching apps.

---

## Requirements

### Must Have
- Circular ring icon in menu bar that fills as usage climbs
- Ring color changes: normal → amber → red as usage approaches limit
- Click to expand dropdown showing all three usage stats with progress bars and reset timers
- Current session usage
- Weekly all-models usage
- Weekly Sonnet-only usage
- Persistent login (stay signed in across restarts until explicit sign-out)
- Distributable as `.dmg` via GitHub Releases

### Nice to Have (later)
- Native notifications when approaching limits (e.g., 80%, 90%)
- Launch at login option
- Configurable color thresholds

### Out of Scope
- iOS / iPadOS version
- Tracking Claude Code CLI usage (separate data source, separate project)
- Any server-side component

---

## Architecture

### Stack
- **Language:** Swift 5.9+
- **Framework:** AppKit (no SwiftUI — lighter, better NSStatusItem support)
- **Auth:** WebKit (WKWebView) with persistent data store
- **Drawing:** Core Graphics (custom ring NSView)
- **Distribution:** GitHub Actions → `.dmg` → GitHub Releases
- **Target:** macOS 13+ (Ventura)

### Components

```
AppDelegate
  └── owns NSStatusItem
  └── owns NSMenu (dropdown)
  └── initializes UsageService + AuthManager on launch

AuthManager
  └── WKWebView with WKWebsiteDataStore.default()
  └── LoginWindowController (shown on first launch or sign-in prompt)
  └── Detects login success via URL observation
  └── Sign-out wipes WKWebsiteDataStore

UsageService
  └── URLSession using WKWebView's shared cookies
  └── Hits claude.ai internal usage API
  └── Timer: polls every 5 minutes
  └── Publishes UsageData via NotificationCenter or delegate

RingView (NSView subclass)
  └── Draws circular arc using CGContext
  └── Input: Float (0.0–1.0), Color state
  └── Used as NSStatusItem button image

MenuViewController
  └── Three UsageRowViews (session, weekly all, weekly sonnet)
  └── Each row: label, progress bar, % label, reset time label
  └── "Last updated" timestamp
  └── Refresh button
  └── Sign Out + Quit at bottom
```

---

## Auth Flow

```
First Launch
  → LoginWindowController opens
  → WKWebView loads claude.ai
  → User logs in normally (2FA supported)
  → WKNavigationDelegate detects redirect to claude.ai/
  → Window closes
  → UsageService begins polling

Subsequent Launches
  → WKWebsiteDataStore.default() already has session cookies
  → UsageService polls immediately
  → Login window never shown

Session Expired (API returns 401)
  → Show "Session expired" label in dropdown
  → "Sign In Again" button triggers LoginWindowController

Sign Out
  → WKWebsiteDataStore.default().removeData(ofTypes: all, modifiedSince: .distantPast)
  → LoginWindowController shown on next open
```

---

## API

The usage data endpoint is discovered by opening `chrome://network-internals` or Charles Proxy while loading `claude.ai/settings/usage`. Expected to be something like:

```
GET https://api.claude.ai/api/usage_status
  or
GET https://claude.ai/api/account/usage
```

Auth is handled automatically via the shared WKWebView cookie session — no token extraction needed.

**Data model:**

```swift
struct UsageData: Codable {
    let currentSession: UsageStat
    let weeklyAllModels: UsageStat
    let weeklySonnetOnly: UsageStat
    let lastUpdated: Date
}

struct UsageStat: Codable {
    let percentUsed: Double        // 0.0 to 1.0
    let resetsAt: Date?            // nil for current session (uses resetsInSeconds)
    let resetsInSeconds: Int?      // nil for weekly stats
}
```

---

## Ring Display Logic

The ring in the menu bar always represents the **highest usage % across all three metrics**. This ensures the user always sees their most critical constraint at a glance.

```swift
let ringValue = max(
    usageData.currentSession.percentUsed,
    usageData.weeklyAllModels.percentUsed,
    usageData.weeklySonnetOnly.percentUsed
)
```

**Color thresholds:**

| Range | Color | NSColor |
|-------|-------|---------|
| 0–59% | Template (monochrome, adapts to light/dark) | `.labelColor` |
| 60–84% | Amber | `#F59E0B` |
| 85–100% | Red | `#EF4444` |

---

## Dropdown Layout

```
┌────────────────────────────────────────┐
│  Claude Usage                    ↻     │
│  Showing: Current Session              │
├────────────────────────────────────────┤
│  Current Session                       │
│  ████████████░░░░  78%  resets in 42m  │
│                                        │
│  Weekly — All Models                   │
│  ███░░░░░░░░░░░░░  19%  Fri 9:00 AM    │
│                                        │
│  Weekly — Sonnet Only                  │
│  █░░░░░░░░░░░░░░░   4%  Sat 2:00 PM   │
│                                        │
│  Last updated: just now                │
├────────────────────────────────────────┤
│  Sign Out                        Quit  │
└────────────────────────────────────────┘
```

---

## Distribution

### GitHub Actions Workflow

On push to `main`:
1. `xcodebuild archive` with Release config
2. Export `.app` from archive
3. Package `.app` into `.dmg` using `create-dmg` (or `hdiutil`)
4. Upload `.dmg` as GitHub Release asset

### Install Flow for Users
1. Download `.dmg` from GitHub Releases
2. Open `.dmg`, drag app to Applications
3. Open app from Applications
4. macOS Gatekeeper prompt: System Settings > Privacy & Security > Open Anyway
5. Login window appears — sign in once
6. App appears in menu bar, stays there

### Future: Code Signing
Joining Apple Developer Program ($99/year) enables proper code signing, which eliminates the Gatekeeper prompt entirely. Not required for alpha/trusted testers.

---

## File Structure

```
claude-usage-widget/                    # GitHub repo root (kebab-case)
  ClaudeUsageWidget/
    AppDelegate.swift
    UsageService.swift
    AuthManager.swift
    RingView.swift
    MenuViewController.swift
    LoginWindowController.swift
    Info.plist
    Assets.xcassets/
      AppIcon.appiconset/
  ClaudeUsageWidget.xcodeproj/
  docs/
    plans/
      2026-03-07-menu-bar-widget-design.md
      2026-03-07-implementation-plan.md
  .github/
    workflows/
      build.yml
  README.md
  CLAUDE.md
  .gitignore
  LICENSE
```

---

## Open Questions (to resolve during implementation)

1. **Exact API endpoint** — needs network inspection of `claude.ai/settings/usage` to confirm URL and response shape
2. **Cookie sharing between WKWebView and URLSession** — need to use `HTTPCookieStorage` shared from WKWebView's data store for API requests, or make API calls from within the WKWebView via JavaScript evaluation
3. **App icon** — simple ring/circle design; can be created with SF Symbols or custom drawn

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| AppKit over SwiftUI | Better NSStatusItem control, lighter weight |
| WKWebView persistent store over Keychain | Native session management, no token extraction |
| Ring shows highest % metric | Single glance shows worst-case constraint |
| 5-minute polling | Balances freshness vs. API load |
| GitHub Actions for CI/CD | Free for public repos, standard Swift build support |
| macOS 13+ target | Avoids legacy API complexity, covers ~90% of active Macs |
