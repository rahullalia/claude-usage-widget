import AppKit
import WebKit

class LoginWindowController: NSWindowController, WKNavigationDelegate {
    weak var authManager: AuthManager?
    private var webView: WKWebView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude"
        window.center()
        self.init(window: window)
        setupWebView()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        window?.contentView = webView
        loadLoginPage()
    }

    private func loadLoginPage() {
        let url = URL(string: "https://claude.ai/login")!
        webView.load(URLRequest(url: url))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        if isSuccessfulLoginURL(url) {
            authManager?.loginDidSucceed()
        }
    }

    // Internal so tests can verify this logic
    func isSuccessfulLoginURL(_ url: URL) -> Bool {
        guard let host = url.host, host.contains("claude.ai") else { return false }
        let path = url.path
        // Success: landed on home, chats, or settings — not on /login or /auth
        let loginPaths = ["/login", "/auth", "/oauth"]
        return !loginPaths.contains(where: { path.hasPrefix($0) })
    }
}
