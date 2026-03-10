import AppKit
import WebKit

class LoginWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate {
    weak var authManager: AuthManager?
    private var webView: WKWebView!
    private var loginDetected = false

    // Holds any OAuth popup windows (e.g. Google sign-in)
    private var popupWindowControllers: [NSWindowController] = []

    // Polls the claude.ai API to detect successful auth — catches login even when
    // SOAuthorizationCoordinator intercepts OAuth and bypasses WKNavigationDelegate entirely
    private var authCheckTimer: Timer?

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
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
        window?.contentView = webView
        loadLoginPage()
    }

    deinit {
        authCheckTimer?.invalidate()
        webView?.removeObserver(self, forKeyPath: "URL")
    }

    // KVO on webView.url catches client-side routing (SPA navigations that don't trigger didFinish)
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "URL", let url = webView?.url {
            checkForSuccessfulLogin(url: url)
        }
    }

    private func loadLoginPage() {
        NSLog("[LOGIN] loadLoginPage called")
        loginDetected = false
        let url = URL(string: "https://claude.ai/login")!
        webView.load(URLRequest(url: url))
        startAuthPolling()
    }

    // MARK: - Auth Polling (API-based)

    private func startAuthPolling() {
        authCheckTimer?.invalidate()
        NSLog("[LOGIN] Starting auth polling timer")
        authCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAuthViaAPI()
        }
    }

    private func stopAuthPolling() {
        authCheckTimer?.invalidate()
        authCheckTimer = nil
    }

    private func checkAuthViaAPI() {
        guard !loginDetected, let webView = webView else {
            stopAuthPolling()
            return
        }
        let js = "return await fetch('/api/organizations').then(r => { if (!r.ok) throw new Error(r.status); return r.json(); }).then(d => d.length > 0 ? 'authenticated' : 'none')"
        webView.callAsyncJavaScript(js, arguments: [:], in: nil, in: .defaultClient) { [weak self] result in
            guard let self = self, !self.loginDetected else { return }
            switch result {
            case .success(let value):
                if let status = value as? String, status == "authenticated" {
                    NSLog("[LOGIN] API auth check succeeded — closing login window")
                    DispatchQueue.main.async {
                        guard !self.loginDetected else { return }
                        self.loginDetected = true
                        self.stopAuthPolling()
                        self.popupWindowControllers.forEach { $0.close() }
                        self.popupWindowControllers.removeAll()
                        self.authManager?.loginDidSucceed()
                    }
                } else {
                    NSLog("[LOGIN] API auth check: not authenticated yet")
                }
            case .failure:
                NSLog("[LOGIN] API auth check: request failed (not logged in yet)")
            }
        }
    }

    // MARK: - Login Detection

    private func checkForSuccessfulLogin(url: URL) {
        guard !loginDetected, isSuccessfulLoginURL(url) else { return }
        loginDetected = true
        stopAuthPolling()
        popupWindowControllers.forEach { $0.close() }
        popupWindowControllers.removeAll()
        authManager?.loginDidSucceed()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check the finishing webView's URL (could be main or popup)
        guard let url = webView.url else { return }
        checkForSuccessfulLogin(url: url)

        // Also check the main webView in case it was redirected by a popup completing
        if webView !== self.webView, let mainURL = self.webView?.url {
            checkForSuccessfulLogin(url: mainURL)
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

    // MARK: - WKUIDelegate (popup handling for Google OAuth)

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Create a popup window for OAuth flows (e.g. Google sign-in)
        let popupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        popupWindow.title = "Sign in"
        popupWindow.center()

        configuration.websiteDataStore = WKWebsiteDataStore.default()
        let popupWebView = WKWebView(frame: popupWindow.contentView!.bounds, configuration: configuration)
        popupWebView.autoresizingMask = [.width, .height]
        popupWebView.navigationDelegate = self
        popupWebView.uiDelegate = self
        popupWindow.contentView?.addSubview(popupWebView)

        let popupController = NSWindowController(window: popupWindow)
        popupController.showWindow(nil)
        popupWindow.makeKeyAndOrderFront(nil)
        popupWindowControllers.append(popupController)

        return popupWebView
    }

    func webViewDidClose(_ webView: WKWebView) {
        // Clean up popup controllers whose webview was closed
        popupWindowControllers.removeAll { $0.window?.contentView?.subviews.first == webView }

        // After OAuth popup closes, reload main webView — if login succeeded,
        // claude.ai will redirect to home (which triggers login detection)
        guard !loginDetected else { return }
        self.webView.load(URLRequest(url: URL(string: "https://claude.ai/")!))
    }
}
