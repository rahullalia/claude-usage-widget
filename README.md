# Claude Usage Widget

A native macOS menu bar app that shows your Claude.ai plan usage at a glance.

A small ring in your menu bar fills up as you use Claude. It turns amber when you're getting close, red when you're almost out. Click it to see the full breakdown.

---

## What It Shows

- **Current session** usage with time until reset
- **Weekly usage** across all models
- **Weekly Sonnet usage** specifically
- Color-coded ring that changes as you approach your limits

---

## Download

Go to [Releases](../../releases) and download the latest `.dmg`. Open it, drag Claude Usage Widget to Applications, and you're done.

On first launch, a window will open asking you to sign in to Claude. Log in once — the app stays signed in until you explicitly sign out.

> **Note:** macOS may show a security prompt the first time ("App from unidentified developer"). Go to System Settings > Privacy & Security > Open Anyway.

---

## Requirements

- macOS 13 (Ventura) or later

---

## Building from Source

Requires Xcode 15+.

```bash
git clone https://github.com/rahullalia/claude-usage-widget.git
cd claude-usage-widget
open ClaudeUsageWidget.xcodeproj
```

Build and run from Xcode, or via CLI:

```bash
xcodebuild -scheme ClaudeUsageWidget -configuration Release
```

---

## Privacy

This app only communicates with `claude.ai`. Your session is stored locally using the system's standard WebKit cookie store (same as Safari). Nothing is sent to any third-party server. No analytics. No telemetry.

---

## Login Notes

The login window uses an embedded WebView. Email/password login works reliably. Google OAuth works in most cases but can occasionally stall on the final redirect step for unsigned apps — if that happens, use email/password instead.

---

## Status

v0.1.2 — functional, running daily. Built for personal use.

---

## License

MIT
