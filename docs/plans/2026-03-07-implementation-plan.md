# Claude Usage Widget — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app that displays Claude.ai session and weekly usage as a color-coded ring, with a click-to-expand dropdown showing full details.

**Architecture:** Swift + AppKit, NSStatusItem for the menu bar icon, WKWebView with persistent data store for auth, Core Graphics for the ring drawing, JavaScript evaluation inside WKWebView to call the claude.ai usage API (avoids all cookie extraction complexity).

**Tech Stack:** Swift 5.9+, AppKit, WebKit, Core Graphics, XCTest, GitHub Actions, create-dmg

---

## Pre-flight Checklist

Before starting, confirm:
- [ ] Xcode 15+ installed (`xcode-select -p` should return a path)
- [ ] Chrome browser open and logged into claude.ai
- [ ] Chrome DevTools MCP available (used in Task 1)
- [ ] GitHub CLI installed (`gh --version`)

---

## Task 1: Discover the API Endpoint

**Goal:** Find the exact URL, request headers, and response shape that powers the `claude.ai/settings/usage` page.

**Files:** None — research only. Record findings in this doc under "API Findings" at the bottom.

**Step 1: Open claude.ai/settings/usage in Chrome**

Navigate to `https://claude.ai/settings/usage` and stay on the page.

**Step 2: Open DevTools Network tab and filter for API calls**

Open Chrome DevTools (Cmd+Option+I), click Network tab, check "Fetch/XHR" filter. Reload the page. Look for any request that returns JSON containing usage percentages or limit data.

**Step 3: Copy the full request details**

Click the matching request. Note:
- Full URL (including query params)
- Request headers (especially `Cookie`, `Authorization`, or `x-session-token`)
- Response body (full JSON)

**Step 4: Record in this plan**

Fill in the "API Findings" section at the bottom of this file.

**Step 5: Commit**

```bash
git add docs/plans/2026-03-07-implementation-plan.md
git commit -m "docs: record API endpoint findings for usage widget"
```

---

## Task 2: Xcode Project Scaffold

**Goal:** Create a minimal macOS agent app (menu bar only, no Dock icon) with the right target settings.

**Files:**
- Create: `ClaudeUsageWidget/` (Xcode project directory — done via Xcode GUI)
- Modify: `ClaudeUsageWidget/Info.plist`
- Create: `ClaudeUsageWidget/ClaudeUsageWidget.entitlements`
- Create: `.gitignore`

**Step 1: Create the Xcode project**

Open Xcode > File > New > Project > macOS > App.
- Product Name: `ClaudeUsageWidget`
- Bundle Identifier: `io.rsla.ClaudeUsageWidget`
- Language: Swift
- Interface: XIB (NOT SwiftUI, NOT Storyboard)
- Uncheck "Include Tests" for now (we add the test target manually)
- Save to: `/Users/rahullalia/lalia/1-Projects/builds/claudeUsageWidget/`

**Step 2: Add test target**

In Xcode: File > New > Target > Unit Testing Bundle.
- Name: `ClaudeUsageWidgetTests`

**Step 3: Configure Info.plist — remove Dock icon**

This makes it a pure menu bar app (no Dock icon, no app switcher entry).

Open `ClaudeUsageWidget/Info.plist`, add:

```xml
<key>LSUIElement</key>
<true/>
```

Or via CLI after project exists:
```bash
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" ClaudeUsageWidget/Info.plist
```

**Step 4: Add entitlements for network access**

Create `ClaudeUsageWidget/ClaudeUsageWidget.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

Note: sandbox is off for alpha. Enables full network access without prompts.

**Step 5: Create .gitignore**

Create `.gitignore` in the project root:

```
# Xcode
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
*.ipa
*.dSYM.zip
*.dSYM
build/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Swift Package Manager
.build/
.swiftpm/

# Archives and DMGs
*.dmg
*.xcarchive
```

**Step 6: Verify it builds**

In Xcode: Product > Build (Cmd+B). Should succeed with a blank window (we'll remove the window in Task 7).

**Step 7: Commit**

```bash
git add ClaudeUsageWidget.xcodeproj/ ClaudeUsageWidget/Info.plist ClaudeUsageWidget/ClaudeUsageWidget.entitlements .gitignore
git commit -m "feat: scaffold Xcode project for ClaudeUsageWidget"
```

---

## Task 3: Data Models + Tests

**Goal:** Define the data structures for usage stats, color state logic, and ring value calculation. Test all logic here — this is the core business logic.

**Files:**
- Create: `ClaudeUsageWidget/Models.swift`
- Create: `ClaudeUsageWidgetTests/ModelsTests.swift`

**Step 1: Write the failing tests first**

Create `ClaudeUsageWidgetTests/ModelsTests.swift`:

```swift
import XCTest
@testable import ClaudeUsageWidget

final class ModelsTests: XCTestCase {

    // MARK: - RingColorState tests

    func test_ringColor_belowAmber() {
        XCTAssertEqual(RingColorState.from(percent: 0.0), .normal)
        XCTAssertEqual(RingColorState.from(percent: 0.59), .normal)
    }

    func test_ringColor_amber() {
        XCTAssertEqual(RingColorState.from(percent: 0.60), .amber)
        XCTAssertEqual(RingColorState.from(percent: 0.84), .amber)
    }

    func test_ringColor_critical() {
        XCTAssertEqual(RingColorState.from(percent: 0.85), .critical)
        XCTAssertEqual(RingColorState.from(percent: 1.0), .critical)
    }

    // MARK: - Ring value (highest % across all stats)

    func test_ringValue_usesHighestMetric() {
        let data = UsageData(
            currentSession: UsageStat(percentUsed: 0.78, resetsAt: nil),
            weeklyAllModels: UsageStat(percentUsed: 0.19, resetsAt: Date()),
            weeklySonnetOnly: UsageStat(percentUsed: 0.04, resetsAt: Date()),
            lastUpdated: Date()
        )
        XCTAssertEqual(data.ringValue, 0.78, accuracy: 0.001)
    }

    func test_ringValue_weeklyCanBeHighest() {
        let data = UsageData(
            currentSession: UsageStat(percentUsed: 0.10, resetsAt: nil),
            weeklyAllModels: UsageStat(percentUsed: 0.92, resetsAt: Date()),
            weeklySonnetOnly: UsageStat(percentUsed: 0.50, resetsAt: Date()),
            lastUpdated: Date()
        )
        XCTAssertEqual(data.ringValue, 0.92, accuracy: 0.001)
    }

    // MARK: - Reset time formatting (resetsAt only — API provides absolute date)

    func test_formatResetsAt_date() {
        // Create a fixed date: Friday at 9:00 AM local time
        var comps = DateComponents()
        comps.weekday = 6   // Friday
        comps.hour = 9
        comps.minute = 0
        let cal = Calendar.current
        let date = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)!
        let stat = UsageStat(percentUsed: 0.2, resetsAt: date)
        XCTAssertTrue(stat.resetsAtDisplay?.contains("9:00") == true)
    }

    func test_formatSessionResetsAt_showsCountdown() {
        // Session reset time is in the future
        let futureDate = Date().addingTimeInterval(2520) // 42 minutes from now
        let stat = UsageStat(percentUsed: 0.5, resetsAt: futureDate)
        // Should display something like "resets in 42m"
        let display = stat.resetsInDisplay
        XCTAssertTrue(display.contains("m") || display.contains("h"), "Expected time display, got: \(display)")
    }

    // MARK: - JSON decoding (matches real API response shape)

    func test_usageData_decodesFromRealAPIShape() throws {
        // This matches the actual claude.ai API response from Task 1
        let json = """
        {
            "five_hour": {
                "utilization": 8.0,
                "resets_at": "2026-03-08T00:00:00.582425+00:00"
            },
            "seven_day": {
                "utilization": 7.0,
                "resets_at": "2026-03-13T16:00:00.582446+00:00"
            },
            "seven_day_sonnet": {
                "utilization": 0.0,
                "resets_at": "2026-03-14T21:00:00.582455+00:00"
            },
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_cowork": null,
            "iguana_necktie": null,
            "extra_usage": {
                "is_enabled": false,
                "monthly_limit": null,
                "used_credits": null,
                "utilization": null
            }
        }
        """.data(using: .utf8)!

        let data = try UsageData.decode(from: json)

        // utilization 8.0 from API → 0.08 after /100 conversion
        XCTAssertEqual(data.currentSession.percentUsed, 0.08, accuracy: 0.001)
        XCTAssertEqual(data.weeklyAllModels.percentUsed, 0.07, accuracy: 0.001)
        XCTAssertEqual(data.weeklySonnetOnly.percentUsed, 0.00, accuracy: 0.001)
        XCTAssertNotNil(data.currentSession.resetsAt)
        XCTAssertNotNil(data.weeklyAllModels.resetsAt)
    }

    func test_ringValue_fromRealData() throws {
        let json = """
        {
            "five_hour": { "utilization": 78.0, "resets_at": "2026-03-08T01:00:00+00:00" },
            "seven_day": { "utilization": 19.0, "resets_at": "2026-03-13T16:00:00+00:00" },
            "seven_day_sonnet": { "utilization": 4.0, "resets_at": "2026-03-14T21:00:00+00:00" },
            "seven_day_oauth_apps": null, "seven_day_opus": null,
            "seven_day_cowork": null, "iguana_necktie": null,
            "extra_usage": { "is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null }
        }
        """.data(using: .utf8)!

        let data = try UsageData.decode(from: json)
        XCTAssertEqual(data.ringValue, 0.78, accuracy: 0.001)
        XCTAssertEqual(data.ringColorState, .amber)
    }
}
```

**Step 2: Run tests — they should all fail**

In Xcode: Cmd+U. Expected: compile error ("UsageData not defined").

**Step 3: Implement Models.swift**

Create `ClaudeUsageWidget/Models.swift`:

```swift
import Foundation
import AppKit

// MARK: - Color State

enum RingColorState: Equatable {
    case normal
    case amber
    case critical

    static func from(percent: Double) -> RingColorState {
        switch percent {
        case ..<0.60: return .normal
        case ..<0.85: return .amber
        default:      return .critical
        }
    }

    var nsColor: NSColor {
        switch self {
        case .normal:   return .labelColor
        case .amber:    return NSColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1)
        case .critical: return NSColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        }
    }
}

// MARK: - Data Models

struct UsageStat {
    let percentUsed: Double   // 0.0 to 1.0 (already divided by 100 from raw API)
    let resetsAt: Date?

    // For session stats: compute countdown from resetsAt vs now
    var resetsInDisplay: String {
        guard let date = resetsAt else { return "" }
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 0 else { return "resetting..." }
        let mins = seconds / 60
        if mins < 60 { return "resets in \(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m > 0 ? "resets in \(h)h \(m)m" : "resets in \(h)h"
    }

    // For weekly stats: display day + time
    var resetsAtDisplay: String? {
        guard let date = resetsAt else { return nil }
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f.string(from: date)
    }
}

struct UsageData {
    let currentSession: UsageStat
    let weeklyAllModels: UsageStat
    let weeklySonnetOnly: UsageStat
    var lastUpdated: Date = Date()

    var ringValue: Double {
        max(currentSession.percentUsed,
            weeklyAllModels.percentUsed,
            weeklySonnetOnly.percentUsed)
    }

    var ringColorState: RingColorState {
        .from(percent: ringValue)
    }

    var dominantLabel: String {
        let vals: [(String, Double)] = [
            ("Current Session", currentSession.percentUsed),
            ("Weekly — All Models", weeklyAllModels.percentUsed),
            ("Weekly — Sonnet Only", weeklySonnetOnly.percentUsed)
        ]
        return vals.max(by: { $0.1 < $1.1 })?.0 ?? "Current Session"
    }
}

// MARK: - API Response Decoding
// Separate raw types for decoding — keeps UsageData clean and not tied to API shape

private struct RawUsageStat: Codable {
    let utilization: Double   // 0–100 from API
    let resets_at: Date
}

private struct RawUsageResponse: Codable {
    let five_hour: RawUsageStat
    let seven_day: RawUsageStat
    let seven_day_sonnet: RawUsageStat?
}

extension UsageData {
    static func decode(from data: Data) throws -> UsageData {
        let decoder = JSONDecoder()
        // API returns ISO 8601 with fractional seconds and timezone offset e.g. "2026-03-08T00:00:00.582425+00:00"
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try fractional seconds first, then without
            let formatters: [ISO8601DateFormatter] = [
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
                { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
            ]
            for f in formatters {
                if let date = f.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        let raw = try decoder.decode(RawUsageResponse.self, from: data)
        return UsageData(
            currentSession: UsageStat(
                percentUsed: raw.five_hour.utilization / 100.0,
                resetsAt: raw.five_hour.resets_at
            ),
            weeklyAllModels: UsageStat(
                percentUsed: raw.seven_day.utilization / 100.0,
                resetsAt: raw.seven_day.resets_at
            ),
            weeklySonnetOnly: UsageStat(
                percentUsed: (raw.seven_day_sonnet?.utilization ?? 0) / 100.0,
                resetsAt: raw.seven_day_sonnet?.resets_at
            )
        )
    }
}
```

**Step 4: Run tests — they should all pass**

Cmd+U. Expected: all green.

**Step 5: Commit**

```bash
git add ClaudeUsageWidget/Models.swift ClaudeUsageWidgetTests/ModelsTests.swift
git commit -m "feat: add UsageData models with ring value and color state logic"
```

---

## Task 4: RingView — Core Graphics Ring Drawing

**Goal:** A reusable `NSView` subclass that draws a circular progress ring. Used to generate the menu bar icon image.

**Files:**
- Create: `ClaudeUsageWidget/RingView.swift`
- No tests needed — visual component, verified by running the app

**Step 1: Implement RingView.swift**

Create `ClaudeUsageWidget/RingView.swift`:

```swift
import AppKit

final class RingView: NSView {

    var progress: Double = 0.0 {   // 0.0 to 1.0
        didSet { needsDisplay = true }
    }

    var colorState: RingColorState = .normal {
        didSet { needsDisplay = true }
    }

    // Renders the ring to an NSImage for use as a menu bar icon
    static func makeImage(progress: Double, colorState: RingColorState, size: CGFloat = 18) -> NSImage {
        let view = RingView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.progress = progress
        view.colorState = colorState

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            view.drawRing(in: ctx, rect: view.bounds)
        }
        image.unlockFocus()

        // For normal state, use as template so it adapts to light/dark menu bar
        if colorState == .normal {
            image.isTemplate = true
        }
        return image
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawRing(in: ctx, rect: dirtyRect)
    }

    private func drawRing(in ctx: CGContext, rect: NSRect) {
        let size = min(rect.width, rect.height)
        let lineWidth: CGFloat = size * 0.14
        let radius = (size - lineWidth) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Background track
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        let bgPath = CGMutablePath()
        bgPath.addArc(center: center, radius: radius,
                      startAngle: -.pi / 2,
                      endAngle: .pi * 1.5,
                      clockwise: false)
        ctx.addPath(bgPath)
        ctx.strokePath()

        guard progress > 0 else { return }

        // Progress arc
        let endAngle = -.pi / 2 + (.pi * 2 * progress)
        colorState.nsColor.setStroke()
        let progressPath = CGMutablePath()
        progressPath.addArc(center: center, radius: radius,
                             startAngle: -.pi / 2,
                             endAngle: endAngle,
                             clockwise: false)
        ctx.addPath(progressPath)
        ctx.strokePath()
    }
}
```

**Step 2: Quick visual test — temporarily hook into AppDelegate**

Open `AppDelegate.swift`. In `applicationDidFinishLaunching`, temporarily add:

```swift
let img = RingView.makeImage(progress: 0.78, colorState: .amber)
// Set as status item image (we build this properly in Task 7)
print("Ring image created: \(img.size)")
```

Run the app. Check console for output. Remove this line after confirming.

**Step 3: Commit**

```bash
git add ClaudeUsageWidget/RingView.swift
git commit -m "feat: add RingView with Core Graphics circular progress drawing"
```

---

## Task 5: AuthManager + LoginWindowController

**Goal:** Manage the WKWebView login session. Persistent across restarts. Show login window when needed, detect success, handle sign-out.

**Files:**
- Create: `ClaudeUsageWidget/AuthManager.swift`
- Create: `ClaudeUsageWidget/LoginWindowController.swift`

**Step 1: Implement AuthManager.swift**

Create `ClaudeUsageWidget/AuthManager.swift`:

```swift
import WebKit

protocol AuthManagerDelegate: AnyObject {
    func authManagerDidSignIn()
    func authManagerDidSignOut()
    func authManagerNeedsLogin()
}

final class AuthManager: NSObject {

    weak var delegate: AuthManagerDelegate?
    private(set) var isSignedIn = false
    private var loginWindow: LoginWindowController?

    // Check if we already have a valid session by inspecting WKWebsiteDataStore cookies
    func checkSession() async {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let hasSession = cookies.contains { $0.domain.contains("claude.ai") && !$0.isExpired }
        await MainActor.run {
            isSignedIn = hasSession
            if hasSession {
                delegate?.authManagerDidSignIn()
            } else {
                delegate?.authManagerNeedsLogin()
            }
        }
    }

    func presentLogin() {
        guard loginWindow == nil else {
            loginWindow?.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = LoginWindowController()
        controller.onSuccess = { [weak self] in
            self?.loginWindow = nil
            self?.isSignedIn = true
            self?.delegate?.authManagerDidSignIn()
        }
        controller.loadWindow()
        controller.window?.makeKeyAndOrderFront(nil)
        loginWindow = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    func signOut() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(
            ofTypes: types,
            modifiedSince: .distantPast
        ) { [weak self] in
            self?.isSignedIn = false
            self?.delegate?.authManagerDidSignOut()
        }
    }
}

extension HTTPCookie {
    var isExpired: Bool {
        guard let expiry = expiresDate else { return false }
        return expiry < Date()
    }
}
```

**Step 2: Implement LoginWindowController.swift**

Create `ClaudeUsageWidget/LoginWindowController.swift`:

```swift
import AppKit
import WebKit

final class LoginWindowController: NSWindowController, WKNavigationDelegate {

    var onSuccess: (() -> Void)?
    private var webView: WKWebView!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude"
        window.center()
        super.init(window: window)
        setupWebView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupWebView() {
        // Use persistent data store — cookies survive app restarts
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        window?.contentView = webView

        let url = URL(string: "https://claude.ai/login")!
        webView.load(URLRequest(url: url))
    }

    // Detect successful login: claude.ai redirects to /new or / after auth
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let path = url.path
        // Successful login lands on /new, /chats, or the root
        if url.host == "claude.ai" && (path == "/" || path == "/new" || path.hasPrefix("/chats")) {
            window?.close()
            onSuccess?()
        }
    }
}
```

**Step 3: Run the app and test login manually**

Wire up temporarily in AppDelegate (see Task 7 for final wiring):

```swift
// Temporary test in applicationDidFinishLaunching:
let auth = AuthManager()
auth.presentLogin()
```

Run app. Login window should appear. Log into claude.ai. Window should close automatically. Check console for any errors.

**Step 4: Commit**

```bash
git add ClaudeUsageWidget/AuthManager.swift ClaudeUsageWidget/LoginWindowController.swift
git commit -m "feat: add AuthManager and LoginWindowController with persistent WKWebView session"
```

---

## Task 6: UsageService — API Fetching

**Goal:** Fetch usage data from the claude.ai API using the authenticated WKWebView session. Parse into `UsageData`. Poll every 5 minutes.

> **Important:** Before implementing this task, Task 1 (API Discovery) must be complete. The exact endpoint URL and JSON shape are required here. Update the JS fetch call with the real endpoint.

**Files:**
- Create: `ClaudeUsageWidget/UsageService.swift`

**Note on cookie strategy:** We use `WKWebView.evaluateJavaScript` to make the API call from within the WebView's authenticated context. This avoids any need to extract or share cookies with URLSession. The WebView already has the session — we just call `fetch()` from JS.

**Step 1: Implement UsageService.swift**

Create `ClaudeUsageWidget/UsageService.swift`:

```swift
import WebKit

protocol UsageServiceDelegate: AnyObject {
    func usageServiceDidUpdate(_ data: UsageData)
    func usageServiceDidFail(error: UsageError)
}

enum UsageError: Error {
    case notAuthenticated
    case orgIdNotFound
    case networkError(String)
    case parseError(String)
}

final class UsageService: NSObject {

    weak var delegate: UsageServiceDelegate?
    private(set) var lastData: UsageData?
    private var orgId: String?

    // Hidden WKWebView — same persistent session as the login WebView
    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        return WKWebView(frame: .zero, configuration: config)
    }()

    private var timer: Timer?

    func startPolling() {
        fetchUsage()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        orgId = nil
    }

    func fetchUsage() {
        ensureOnClaudeAI { [weak self] in
            self?.resolveOrgId { orgId in
                guard let orgId else { return }
                self?.fetchUsageForOrg(orgId)
            }
        }
    }

    // MARK: - Private

    private func ensureOnClaudeAI(then block: @escaping () -> Void) {
        if webView.url?.host == "claude.ai" {
            block()
        } else {
            // Navigate to a lightweight page so cookies are in scope for JS fetch
            webView.load(URLRequest(url: URL(string: "https://claude.ai/settings/usage")!))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: block)
        }
    }

    // Step 1: get the org_id dynamically — every user has a different one
    private func resolveOrgId(completion: @escaping (String?) -> Void) {
        if let cached = orgId { completion(cached); return }

        let js = """
        (async function() {
            try {
                const res = await fetch('/api/organizations', { credentials: 'include' });
                if (!res.ok) return JSON.stringify({ error: 'http_' + res.status });
                const orgs = await res.json();
                const active = orgs.find(o => o.active !== false) || orgs[0];
                return active ? JSON.stringify({ uuid: active.uuid }) : JSON.stringify({ error: 'no_org' });
            } catch(e) { return JSON.stringify({ error: e.message }); }
        })()
        """

        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let obj = try? JSONDecoder().decode([String: String].self, from: data),
                  let uuid = obj["uuid"] else {
                self?.delegate?.usageServiceDidFail(error: .orgIdNotFound)
                completion(nil)
                return
            }
            self?.orgId = uuid
            completion(uuid)
        }
    }

    // Step 2: fetch usage for the resolved org_id
    private func fetchUsageForOrg(_ orgId: String) {
        let js = """
        (async function() {
            try {
                const res = await fetch('/api/organizations/\(orgId)/usage', {
                    credentials: 'include',
                    headers: { 'Accept': 'application/json' }
                });
                if (res.status === 401) return JSON.stringify({ error: 'unauthenticated' });
                if (!res.ok) return JSON.stringify({ error: 'http_' + res.status });
                return JSON.stringify(await res.json());
            } catch(e) { return JSON.stringify({ error: e.message }); }
        })()
        """

        webView.evaluateJavaScript(js) { [weak self] result, error in
            if let error = error {
                self?.delegate?.usageServiceDidFail(error: .networkError(error.localizedDescription))
                return
            }
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8) else {
                self?.delegate?.usageServiceDidFail(error: .parseError("No JSON returned"))
                return
            }
            self?.parseResponse(data)
        }
    }

    private func parseResponse(_ data: Data) {
        // Check for error sentinel
        if let obj = try? JSONDecoder().decode([String: String].self, from: data),
           let err = obj["error"] {
            if err == "unauthenticated" {
                delegate?.usageServiceDidFail(error: .notAuthenticated)
            } else {
                delegate?.usageServiceDidFail(error: .networkError(err))
            }
            return
        }
        do {
            let usageData = try UsageData.decode(from: data)
            lastData = usageData
            delegate?.usageServiceDidUpdate(usageData)
        } catch {
            delegate?.usageServiceDidFail(error: .parseError(error.localizedDescription))
        }
    }
}
```

**Step 2: Write a parsing test with the real JSON shape**

Create `ClaudeUsageWidgetTests/UsageServiceTests.swift`:

```swift
import XCTest
@testable import ClaudeUsageWidget

final class UsageServiceTests: XCTestCase {

    func test_parseRealAPIResponse() throws {
        // Real response shape from claude.ai/api/organizations/{id}/usage
        let json = """
        {
            "five_hour": { "utilization": 8.0, "resets_at": "2026-03-08T00:00:00.582425+00:00" },
            "seven_day": { "utilization": 7.0, "resets_at": "2026-03-13T16:00:00.582446+00:00" },
            "seven_day_sonnet": { "utilization": 0.0, "resets_at": "2026-03-14T21:00:00.582455+00:00" },
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_cowork": null,
            "iguana_necktie": null,
            "extra_usage": { "is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null }
        }
        """.data(using: .utf8)!

        let data = try UsageData.decode(from: json)

        // 8.0 from API → 0.08 after /100
        XCTAssertEqual(data.currentSession.percentUsed, 0.08, accuracy: 0.001)
        XCTAssertEqual(data.weeklyAllModels.percentUsed, 0.07, accuracy: 0.001)
        XCTAssertEqual(data.weeklySonnetOnly.percentUsed, 0.00, accuracy: 0.001)
        XCTAssertNotNil(data.currentSession.resetsAt)
        XCTAssertNotNil(data.weeklyAllModels.resetsAt)
        // Verify all values are in valid 0–1 range
        XCTAssertLessThanOrEqual(data.currentSession.percentUsed, 1.0)
        XCTAssertLessThanOrEqual(data.weeklyAllModels.percentUsed, 1.0)
    }
}
```

**Step 3: Run tests**

Cmd+U. All tests should pass.

**Step 4: Commit**

```bash
git add ClaudeUsageWidget/UsageService.swift ClaudeUsageWidgetTests/UsageServiceTests.swift
git commit -m "feat: add UsageService with JS-based API fetching and 5-minute polling"
```

---

## Task 7: MenuView — Dropdown UI

**Goal:** Build the click-to-expand dropdown as a custom NSView panel. Three usage rows with progress bars, labels, reset times.

**Files:**
- Create: `ClaudeUsageWidget/MenuView.swift`

**Step 1: Implement MenuView.swift**

Create `ClaudeUsageWidget/MenuView.swift`:

```swift
import AppKit

final class MenuView: NSView {

    var usageData: UsageData? { didSet { updateUI() } }
    var onRefresh: (() -> Void)?
    var onSignOut: (() -> Void)?

    private let titleLabel = makeLabel("Claude Usage", size: 13, weight: .semibold)
    private let dominantLabel = makeLabel("", size: 10, weight: .regular, color: .secondaryLabelColor)
    private let refreshButton: NSButton = {
        let b = NSButton(title: "↻", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 14)
        return b
    }()

    private let sessionRow = UsageRowView(label: "Current Session")
    private let weeklyAllRow = UsageRowView(label: "Weekly — All Models")
    private let weeklySonnetRow = UsageRowView(label: "Weekly — Sonnet Only")

    private let lastUpdatedLabel = makeLabel("Last updated: —", size: 10, weight: .regular, color: .secondaryLabelColor)
    private let separator = NSBox()
    private let signOutButton: NSButton = {
        let b = NSButton(title: "Sign Out", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 12)
        return b
    }()
    private let quitButton: NSButton = {
        let b = NSButton(title: "Quit", target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 12)
        return b
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        refreshButton.target = self
        refreshButton.action = #selector(didTapRefresh)
        signOutButton.target = self
        signOutButton.action = #selector(didTapSignOut)
        quitButton.target = self
        quitButton.action = #selector(didTapQuit)

        separator.boxType = .separator

        let header = NSStackView(views: [titleLabel, NSView(), refreshButton])
        header.orientation = .horizontal

        let stack = NSStackView(views: [
            header,
            dominantLabel,
            separator,
            sessionRow,
            weeklyAllRow,
            weeklySonnetRow,
            lastUpdatedLabel,
            NSBox().also { $0.boxType = .separator },
            buildFooter()
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 280)
        ])
    }

    private func buildFooter() -> NSView {
        let v = NSStackView(views: [signOutButton, NSView(), quitButton])
        v.orientation = .horizontal
        return v
    }

    private func updateUI() {
        guard let data = usageData else {
            sessionRow.update(percent: 0, resetLabel: "—")
            weeklyAllRow.update(percent: 0, resetLabel: "—")
            weeklySonnetRow.update(percent: 0, resetLabel: "—")
            return
        }

        dominantLabel.stringValue = "Showing: \(data.dominantLabel)"

        sessionRow.update(
            percent: data.currentSession.percentUsed,
            resetLabel: data.currentSession.resetsInDisplay
        )
        weeklyAllRow.update(
            percent: data.weeklyAllModels.percentUsed,
            resetLabel: data.weeklyAllModels.resetsAtDisplay ?? "—"
        )
        weeklySonnetRow.update(
            percent: data.weeklySonnetOnly.percentUsed,
            resetLabel: data.weeklySonnetOnly.resetsAtDisplay ?? "—"
        )

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        lastUpdatedLabel.stringValue = "Last updated: \(formatter.localizedString(for: data.lastUpdated, relativeTo: Date()))"
    }

    @objc private func didTapRefresh() { onRefresh?() }
    @objc private func didTapSignOut() { onSignOut?() }
    @objc private func didTapQuit() { NSApp.terminate(nil) }
}

// MARK: - UsageRowView

final class UsageRowView: NSView {
    private let titleLabel: NSTextField
    private let progressBar = NSProgressIndicator()
    private let percentLabel = makeLabel("0%", size: 11, weight: .medium)
    private let resetLabel = makeLabel("", size: 10, weight: .regular, color: .secondaryLabelColor)

    init(label: String) {
        titleLabel = makeLabel(label, size: 11, weight: .semibold)
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        progressBar.style = .bar
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.isIndeterminate = false

        let topRow = NSStackView(views: [titleLabel, NSView(), percentLabel, resetLabel])
        topRow.orientation = .horizontal
        topRow.spacing = 4

        let stack = NSStackView(views: [topRow, progressBar])
        stack.orientation = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressBar.widthAnchor.constraint(equalToConstant: 248)
        ])
    }

    func update(percent: Double, resetLabel: String) {
        percentLabel.stringValue = "\(Int(percent * 100))%"
        self.resetLabel.stringValue = resetLabel
        progressBar.doubleValue = percent
    }
}

// MARK: - Helpers

private func makeLabel(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
    let f = NSTextField(labelWithString: string)
    f.font = .systemFont(ofSize: size, weight: weight)
    f.textColor = color
    f.isEditable = false
    f.isBordered = false
    f.backgroundColor = .clear
    return f
}

// Convenience for inline property setting
extension NSObject {
    @discardableResult
    func also(_ block: (Self) -> Void) -> Self { block(self); return self }
}
```

**Step 2: Verify it compiles**

Cmd+B. Should compile cleanly.

**Step 3: Commit**

```bash
git add ClaudeUsageWidget/MenuView.swift
git commit -m "feat: add MenuView dropdown with three usage rows and progress bars"
```

---

## Task 8: AppDelegate — Wire Everything Together

**Goal:** Connect all components. Set up NSStatusItem with ring icon. Handle auth state, show menu, trigger refresh.

**Files:**
- Modify: `ClaudeUsageWidget/AppDelegate.swift` (replace all content)

**Step 1: Rewrite AppDelegate.swift**

```swift
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate,
                         AuthManagerDelegate, UsageServiceDelegate {

    private var statusItem: NSStatusItem!
    private let authManager = AuthManager()
    private let usageService = UsageService()
    private var menuView: MenuView!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        authManager.delegate = self
        usageService.delegate = self
        Task { await authManager.checkSession() }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateRingIcon(progress: 0, colorState: .normal)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    private func setupPopover() {
        menuView = MenuView(frame: .zero)
        menuView.onRefresh = { [weak self] in self?.usageService.fetchUsage() }
        menuView.onSignOut = { [weak self] in self?.authManager.signOut() }

        let vc = NSViewController()
        vc.view = menuView

        popover = NSPopover()
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 220)
    }

    private func updateRingIcon(progress: Double, colorState: RingColorState) {
        let image = RingView.makeImage(progress: progress, colorState: colorState)
        statusItem.button?.image = image
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - AuthManagerDelegate

    func authManagerDidSignIn() {
        usageService.startPolling()
    }

    func authManagerDidSignOut() {
        usageService.stopPolling()
        updateRingIcon(progress: 0, colorState: .normal)
        menuView.usageData = nil
        authManager.presentLogin()
    }

    func authManagerNeedsLogin() {
        authManager.presentLogin()
    }

    // MARK: - UsageServiceDelegate

    func usageServiceDidUpdate(_ data: UsageData) {
        DispatchQueue.main.async { [weak self] in
            self?.menuView.usageData = data
            self?.updateRingIcon(progress: data.ringValue, colorState: data.ringColorState)
        }
    }

    func usageServiceDidFail(error: UsageError) {
        DispatchQueue.main.async { [weak self] in
            switch error {
            case .notAuthenticated:
                self?.authManager.presentLogin()
            case .networkError(let msg):
                print("UsageService network error: \(msg)")
            case .parseError(let msg):
                print("UsageService parse error: \(msg)")
            }
        }
    }
}
```

**Step 2: Delete the auto-generated MainMenu.xib or storyboard**

If Xcode added a `Main.storyboard` or `MainMenu.xib`, delete it. In Info.plist, remove `NSMainStoryboardFile` or `NSMainNibFile` key — the `@main` attribute on AppDelegate handles startup.

**Step 3: Run the full app**

Cmd+R. The app should:
1. Show a ring icon in the menu bar
2. Open login window if not authenticated
3. After login, close window and start polling
4. Ring should update with usage data

**Step 4: Commit**

```bash
git add ClaudeUsageWidget/AppDelegate.swift
git commit -m "feat: wire AppDelegate with NSStatusItem, auth flow, and usage polling"
```

---

## Task 9: GitHub Repo Setup

**Goal:** Create the public GitHub repo, push all code, set up initial release structure.

**Files:**
- Create: `LICENSE`

**Step 1: Create LICENSE**

Create `LICENSE` (MIT):

```
MIT License

Copyright (c) 2026 Rahul Lalia

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Step 2: Create GitHub repo**

```bash
cd /Users/rahullalia/lalia/1-Projects/builds/claudeUsageWidget
gh repo create rahullalia/claude-usage-widget --public --description "macOS menu bar widget for Claude.ai plan usage" --source . --push
```

**Step 3: Verify push**

```bash
gh repo view rahullalia/claude-usage-widget
```

Expected: repo exists, files visible.

**Step 4: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license"
git push
```

---

## Task 10: GitHub Actions Build Pipeline

**Goal:** Automate `.dmg` creation on every push to `main`. Attach to GitHub Releases.

**Files:**
- Create: `.github/workflows/build.yml`

**Step 1: Install create-dmg locally to test**

```bash
brew install create-dmg
```

**Step 2: Test manual DMG creation**

```bash
# Build the app first
xcodebuild -scheme ClaudeUsageWidget \
  -configuration Release \
  -archivePath build/ClaudeUsageWidget.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/ClaudeUsageWidget.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

Create `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
```

```bash
# Create DMG
create-dmg \
  --volname "Claude Usage Widget" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 185 \
  "ClaudeUsageWidget.dmg" \
  "build/export/ClaudeUsageWidget.app"
```

**Step 3: Create GitHub Actions workflow**

Create `.github/workflows/build.yml`:

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Build Archive
        run: |
          xcodebuild -scheme ClaudeUsageWidget \
            -configuration Release \
            -archivePath $RUNNER_TEMP/ClaudeUsageWidget.xcarchive \
            archive

      - name: Export App
        run: |
          xcodebuild -exportArchive \
            -archivePath $RUNNER_TEMP/ClaudeUsageWidget.xcarchive \
            -exportPath $RUNNER_TEMP/export \
            -exportOptionsPlist ExportOptions.plist

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Create DMG
        run: |
          create-dmg \
            --volname "Claude Usage Widget" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --app-drop-link 450 185 \
            $RUNNER_TEMP/ClaudeUsageWidget.dmg \
            $RUNNER_TEMP/export/ClaudeUsageWidget.app

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: ${{ runner.temp }}/ClaudeUsageWidget.dmg
          generate_release_notes: true
```

**Step 4: Tag and trigger first release**

```bash
git tag v0.1.0-alpha
git push origin v0.1.0-alpha
```

Watch GitHub Actions complete. Check Releases page for `.dmg` artifact.

**Step 5: Commit workflow**

```bash
git add .github/workflows/build.yml ExportOptions.plist
git commit -m "ci: add GitHub Actions build pipeline and DMG release workflow"
git push
```

---

## Task 11: Polish + Final README Update

**Goal:** Screenshot, install instructions, known issues, share link with testers.

**Step 1: Take a screenshot of the working app**

Run the app with real data. Screenshot the menu bar ring and the open dropdown. Save to `docs/screenshots/` (create the folder).

**Step 2: Update README with screenshot**

Add to the top of README.md:

```markdown
![Claude Usage Widget showing 78% session usage ring and dropdown](docs/screenshots/preview.png)
```

**Step 3: Add Known Issues section to README**

```markdown
## Known Issues (Alpha)

- macOS Gatekeeper will prompt on first open — go to System Settings > Privacy & Security > Open Anyway
- If usage data doesn't load, sign out and sign back in
- API endpoint may change without notice (this uses an unofficial internal endpoint)
```

**Step 4: Final commit and tag**

```bash
git add README.md docs/screenshots/
git commit -m "docs: add screenshot and known issues to README"
git tag v0.1.0
git push && git push --tags
```

---

## API Findings

**Endpoint:** `GET https://claude.ai/api/organizations/{org_id}/usage`

**Method:** GET

**Auth:** Session cookie via WKWebView (no explicit headers needed — cookies sent automatically)

**Important:** The `org_id` is user-specific and must be discovered dynamically after login. It cannot be hardcoded. Discovery approach: fetch `GET /api/organizations` after login to get the user's org list, use the first active org's `uuid` field.

**Sample response:**
```json
{
    "five_hour": {
        "utilization": 8.0,
        "resets_at": "2026-03-08T00:00:00.582425+00:00"
    },
    "seven_day": {
        "utilization": 7.0,
        "resets_at": "2026-03-13T16:00:00.582446+00:00"
    },
    "seven_day_oauth_apps": null,
    "seven_day_opus": null,
    "seven_day_sonnet": {
        "utilization": 0.0,
        "resets_at": "2026-03-14T21:00:00.582455+00:00"
    },
    "seven_day_cowork": null,
    "iguana_necktie": null,
    "extra_usage": {
        "is_enabled": false,
        "monthly_limit": null,
        "used_credits": null,
        "utilization": null
    }
}
```

**Critical notes for implementation:**
- `utilization` is **0–100** (percent), NOT 0.0–1.0. Divide by 100 before storing in `UsageStat.percentUsed`.
- `five_hour` = current session (5-hour rolling window)
- `seven_day` = weekly all-models
- `seven_day_sonnet` = weekly Sonnet only
- Fields like `seven_day_opus`, `seven_day_cowork`, `iguana_necktie` are null for this plan — ignore them
- `resets_at` is ISO 8601 with timezone offset (e.g. `+00:00`) — use `iso8601` date decoding strategy

---

## Blockers / Decisions Log

| Date | Item | Decision |
|------|------|----------|
| 2026-03-07 | Cookie strategy | Use JS eval in WKWebView — avoids all cookie extraction complexity |
| 2026-03-07 | UI framework | AppKit (no SwiftUI) — better NSStatusItem, lighter binary |
| 2026-03-07 | API endpoint | GET /api/organizations/{org_id}/usage — confirmed via DevTools |
| 2026-03-07 | org_id discovery | Fetch GET /api/organizations, use first active org's uuid field |
| 2026-03-07 | utilization scale | API returns 0–100, divide by 100 before storing in UsageStat.percentUsed |
