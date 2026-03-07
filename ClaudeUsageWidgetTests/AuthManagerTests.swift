import XCTest
@testable import ClaudeUsageWidget

final class AuthManagerTests: XCTestCase {

    // MARK: - LoginWindowController URL detection

    func test_isSuccessfulLoginURL_homePageIsSuccess() {
        let vc = LoginWindowController()
        let url = URL(string: "https://claude.ai/")!
        XCTAssertTrue(vc.isSuccessfulLoginURL(url))
    }

    func test_isSuccessfulLoginURL_loginPageIsNotSuccess() {
        let vc = LoginWindowController()
        let url = URL(string: "https://claude.ai/login")!
        XCTAssertFalse(vc.isSuccessfulLoginURL(url))
    }

    func test_isSuccessfulLoginURL_authPageIsNotSuccess() {
        let vc = LoginWindowController()
        let url = URL(string: "https://claude.ai/auth/callback")!
        XCTAssertFalse(vc.isSuccessfulLoginURL(url))
    }

    func test_isSuccessfulLoginURL_chatsIsSuccess() {
        let vc = LoginWindowController()
        let url = URL(string: "https://claude.ai/chats")!
        XCTAssertTrue(vc.isSuccessfulLoginURL(url))
    }

    func test_isSuccessfulLoginURL_settingsIsSuccess() {
        let vc = LoginWindowController()
        let url = URL(string: "https://claude.ai/settings/usage")!
        XCTAssertTrue(vc.isSuccessfulLoginURL(url))
    }

    func test_isSuccessfulLoginURL_nonClaudeURLIsNotSuccess() {
        let vc = LoginWindowController()
        let url = URL(string: "https://google.com/")!
        XCTAssertFalse(vc.isSuccessfulLoginURL(url))
    }

    // MARK: - AuthManager initial state

    func test_authManager_startsUnauthenticated() {
        let manager = AuthManager()
        XCTAssertFalse(manager.isAuthenticated)
    }
}
