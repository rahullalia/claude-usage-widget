import AppKit
import WebKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Components

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var menuViewController: MenuViewController!
    private var authManager: AuthManager!
    private var usageService: UsageService?

    // WKWebView lives here permanently — it holds the session cookies
    private var webView: WKWebView!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWebView()
        setupStatusItem()
        setupPopover()
        setupAuthManager()
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        webView = WKWebView(frame: .zero, configuration: config)
        // Load claude.ai so the webview has the right origin for fetch() calls
        webView.load(URLRequest(url: URL(string: "https://claude.ai")!))
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon(progress: 0.0, colorState: .normal)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }

    private func setupPopover() {
        menuViewController = MenuViewController()
        menuViewController.onRefresh = { [weak self] in
            self?.usageService?.fetch()
        }
        menuViewController.onSignOut = { [weak self] in
            self?.signOut()
        }

        popover = NSPopover()
        popover.contentViewController = menuViewController
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 260)
    }

    private func setupAuthManager() {
        authManager = AuthManager()
        authManager.delegate = self
        authManager.checkAuthStatus()
    }

    // MARK: - Status Icon

    private func updateStatusIcon(progress: Double, colorState: RingColorState) {
        let image = RingView.image(progress: progress, colorState: colorState)
        statusItem.button?.image = image
        statusItem.button?.imageScaling = .scaleProportionallyDown
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Usage Service

    private func startUsageService() {
        if usageService == nil {
            usageService = UsageService(webView: webView)
            usageService?.delegate = self
        }
        menuViewController.showLoading()
        usageService?.startPolling()
    }

    // MARK: - Sign Out

    private func signOut() {
        usageService?.stopPolling()
        usageService?.resetCache()
        usageService = nil
        updateStatusIcon(progress: 0.0, colorState: .normal)
        authManager.signOut()
    }
}

// MARK: - AuthManagerDelegate

extension AppDelegate: AuthManagerDelegate {
    func authManagerDidAuthenticate(_ manager: AuthManager) {
        startUsageService()
    }

    func authManagerDidSignOut(_ manager: AuthManager) {
        // Login window is shown by AuthManager automatically — nothing to do here
    }
}

// MARK: - UsageServiceDelegate

extension AppDelegate: UsageServiceDelegate {
    func usageService(_ service: UsageService, didUpdate data: UsageData) {
        updateStatusIcon(progress: data.ringValue, colorState: data.ringColorState)
        menuViewController.update(with: data)
    }

    func usageService(_ service: UsageService, didFailWith error: UsageServiceError) {
        let message: String
        switch error {
        case .notAuthenticated:
            message = "Not signed in"
        case .orgIdNotFound:
            message = "Could not find org"
        case .networkError(let desc):
            message = desc
        case .parseError(let desc):
            message = desc
        }
        menuViewController.showError(message)
    }
}
