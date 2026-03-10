# CLAUDE.md — claudeUsageWidget

## Project Overview

A native macOS menu bar app (Swift + AppKit) that displays Claude.ai plan usage at a glance. Shows a circular ring progress indicator in the menu bar that fills up as usage climbs, with color-coded states. Click to expand a dropdown with full usage details.

**GitHub Repo:** `rahullalia/claude-usage-widget` ([github.com/rahullalia/claude-usage-widget](https://github.com/rahullalia/claude-usage-widget))
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
    MenuView.swift           # Popover UI (progress bars, segmented toggle, auth states)
    RefreshIcon.swift        # Teenyicons refresh SVG drawn via CGPath
    Models.swift             # UsageData, UsageStat, RingColorState, RingMetricMode
    LoginWindowController.swift  # WKWebView login window
    main.swift               # App entry point (XCTest-aware)
    Info.plist
    Assets.xcassets/
  ClaudeUsageWidget.xcodeproj/
  docs/
    plans/
      2026-03-07-menu-bar-widget-design.md   # Approved design doc
      2026-03-07-implementation-plan.md       # Step-by-step build plan
      2026-03-10-v0.2.0-popover-redesign.md  # v0.2.0 design spec
      2026-03-10-v0.2.0-implementation-plan.md # v0.2.0 build plan
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
- **`main.swift` instead of `@main`** — explicit `app.delegate = delegate` before `app.run()` is required; `@main` does not wire NSApp.delegate without a nib file, so `applicationDidFinishLaunching` never fires without this
- **`setupStatusItem()` must run before `setupWebView()`** — WKWebView init triggers WebKit process launch (Mach IPC) which can interfere with NSStatusBar registration on macOS Sonoma if status item hasn't been created yet
- **`callAsyncJavaScript` not `evaluateJavaScript`** — fetch() returns a Promise; `evaluateJavaScript` returns the Promise object itself (unsupported type error); `callAsyncJavaScript` properly awaits it
- **Navigation delegate gates polling start** — `startPolling()` is called only in `webView(_:didFinish:)` after claude.ai loads, not immediately after `webView.load()`, otherwise JS runs from blank origin with no cookies
- **`xcodegen` manages the Xcode project** — edit `project.yml`, run `xcodegen generate`, never hand-edit `.xcodeproj`
- **`main.swift` detects XCTest** — when running under XCTest, a minimal `TestAppDelegate` is used instead of `AppDelegate` to avoid launching the full UI (NSStatusItem, WKWebView, etc.) which crashes the test runner
- **Ring metric toggle** — `RingMetricMode` enum (`.session` / `.weekly`) persisted in `UserDefaults`; segmented control in popover lets user switch what the ring shows
- **Auth-aware footer** — footer button swaps between "Sign In" and "Sign Out" based on auth state; "Sign In" opens the login window
- **Custom RefreshButton** — draws the teenyicons refresh SVG via `CGPath` at render time; strokes with `NSColor.secondaryLabelColor` for automatic light/dark adaptation

---

## Auth Flow

1. First launch: login window opens with WKWebView pointing to `claude.ai`
2. User logs in normally (supports 2FA, Google OAuth, etc.)
3. App detects successful login by observing URL redirect to `claude.ai` homepage
4. Session cookie persisted in `WKWebsiteDataStore.default()` — survives app restarts
5. Sign Out: calls `WKWebsiteDataStore.default().removeData(...)` to wipe session

### Google OAuth caveat

`SOAuthorizationCoordinator` intercepts Google sign-in attempts in unsigned WKWebView apps and can block them. The `WKUIDelegate` popup handler (`webView(_:createWebViewWith:for:windowFeatures:)`) is implemented and handles most cases, but Google occasionally rejects unsigned apps at the final OAuth redirect step. **Workaround:** Add an email/password to the Claude account at claude.ai → Settings → Account — this makes login reliable without needing Apple Developer Program membership.

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

Ring shows **session usage** by default (configurable via the popover toggle). In weekly mode, it shows the highest % across weekly metrics.

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

# Regenerate Xcode project after editing project.yml
xcodegen generate

# Regenerate app icon PNGs (after icon design changes)
swift makeIcon.swift

# Build from CLI
xcodebuild -scheme ClaudeUsageWidget -configuration Release

# Create DMG (after build)
create-dmg ...   # see docs/plans/implementation-plan.md
```

---

## Status

- [x] Design approved
- [x] Implementation plan written
- [x] Xcode project scaffolded
- [x] Auth (WKWebView login + persistent session)
- [x] API endpoint identified + UsageService built
- [x] Ring drawing (Core Graphics)
- [x] Dropdown menu UI
- [x] Color state logic
- [x] GitHub Actions build pipeline
- [x] GitHub repo created + first release
- [x] App icon (amber ring, dark slate bg) — `makeIcon.swift` generates all sizes
- [x] Menu bar shows real RingView ring (not placeholder)
- [x] Debug prints removed — production-clean code
- [x] v0.1.2 tagged and pushed — DMG building via GitHub Actions
- [x] v0.2.0: Popover redesign — custom progress bars, semantic colors, light/dark mode
- [x] v0.2.0: Ring metric toggle — Session/Weekly segmented control with UserDefaults persistence
- [x] v0.2.0: Auth-aware footer — Sign In/Sign Out swap, signed-out empty state
- [x] v0.2.0: Custom refresh icon — teenyicons SVG drawn via CGPath
- [x] v0.2.0: Test runner fix — XCTest-aware main.swift

---

## Known Issues / Gotchas

- WebContent sandbox errors in Xcode console are **expected noise** — WKWebView subprocess cannot access pasteboard/audio/launchservices when unsigned. Does not affect functionality.
- `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` must be set in `project.yml` target settings for the app icon to compile. xcodegen does not add this automatically.
- Finder may cache old app icons. Copy the `.app` to Desktop or run `killall Dock` to force refresh.

---

## Last Updated

2026-03-10
