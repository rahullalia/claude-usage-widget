import AppKit

let app = NSApplication.shared

if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
    // Running under XCTest — use minimal delegate to avoid launching full UI
    class TestAppDelegate: NSObject, NSApplicationDelegate {}
    let testDelegate = TestAppDelegate()
    app.delegate = testDelegate
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
}

app.run()
