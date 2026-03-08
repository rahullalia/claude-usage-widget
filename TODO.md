# ClaudeUsageWidget — TODO

Last updated: 2026-03-08

## High Priority

- [ ] **Add email/password to Claude account** (user action, not code) — go to claude.ai → Settings → Account → add password. Makes re-login reliable without depending on Google OAuth.
- [ ] **Verify GitHub Actions DMG build succeeded** — check Actions tab on `rahullalia/claude-usage-widget` for v0.1.2 tag. Download and test the DMG to confirm standalone install works.
- [ ] **Install from DMG to /Applications** — once DMG is confirmed working, install permanently so app survives without Xcode

## Medium Priority

- [ ] **Launch at login** — add `SMAppService.mainApp.register()` (macOS 13+) so the widget starts automatically on boot without needing Xcode open
- [ ] **Add "Refresh" button to popover** — currently refresh is wired but the MenuViewController may not expose a visible button; confirm it exists and works
- [ ] **Handle auth expiry gracefully** — if the claude.ai session expires, the app currently shows an error in the popover but doesn't automatically prompt re-login. Should detect auth failure and open the login window.

## Low Priority / Nice to Have

- [ ] **Apple Developer Program** — $99/year, enables code signing, removes Gatekeeper "unidentified developer" prompt for all users
- [ ] **Improve Google OAuth** — once signed, `com.apple.security.network.client` + proper entitlements may resolve `SOAuthorizationCoordinator` blocking. Research required.
- [ ] **Notification when usage hits 80%** — `UNUserNotificationCenter` one-time alert as usage crosses threshold
- [ ] **Menu bar tooltip** — show exact % on hover over the ring icon via `statusItem.button?.toolTip`
- [ ] **Dark/light mode ring adaptation** — at 0-59% the ring is monochrome; ensure it renders correctly on both light and dark menu bars (test both)

## Completed (this sprint, 2026-03-07 to 2026-03-08)

- [x] Fixed `applicationDidFinishLaunching` never firing (`@main` → `main.swift`)
- [x] Fixed menu bar icon not appearing (reordered init: status item before webview)
- [x] Fixed Google OAuth popup blocked (implemented `WKUIDelegate` popup handler)
- [x] Fixed usage data not loading (`evaluateJavaScript` → `callAsyncJavaScript` for Promise handling)
- [x] Fixed polling before page loaded (gates `startPolling()` behind `WKNavigationDelegate.didFinish`)
- [x] App icon generated and compiling (`makeIcon.swift`, `ASSETCATALOG_COMPILER_APPICON_NAME`)
- [x] Menu bar shows real ring (replaced placeholder SF Symbol)
- [x] Removed all debug print statements
- [x] v0.1.2 tagged and pushed to GitHub
