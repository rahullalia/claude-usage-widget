import Foundation
import WebKit

protocol AuthManagerDelegate: AnyObject {
    func authManagerDidAuthenticate(_ manager: AuthManager)
    func authManagerDidSignOut(_ manager: AuthManager)
}

class AuthManager: NSObject {
    weak var delegate: AuthManagerDelegate?
    private(set) var isAuthenticated = false
    private var loginWindow: LoginWindowController?

    // Call on app launch. If session cookies exist, fires delegate immediately.
    // Otherwise shows login window.
    func checkAuthStatus() {
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            DispatchQueue.main.async {
                let hasClaudeCookies = records.contains { $0.displayName.contains("claude.ai") }
                if hasClaudeCookies {
                    self.isAuthenticated = true
                    self.delegate?.authManagerDidAuthenticate(self)
                } else {
                    self.showLoginWindow()
                }
            }
        }
    }

    func signOut() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.delegate?.authManagerDidSignOut(self)
                self.showLoginWindow()
            }
        }
    }

    func showLoginWindow() {
        if loginWindow == nil {
            loginWindow = LoginWindowController()
            loginWindow?.authManager = self
        }
        loginWindow?.showWindow(nil)
        loginWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Called by LoginWindowController when login is detected
    func loginDidSucceed() {
        loginWindow?.close()
        loginWindow = nil
        isAuthenticated = true
        delegate?.authManagerDidAuthenticate(self)
    }
}
