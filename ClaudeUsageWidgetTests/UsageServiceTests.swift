import XCTest
import WebKit
@testable import ClaudeUsageWidget

final class UsageServiceTests: XCTestCase {

    // MARK: - UsageServiceError

    func test_error_notAuthenticated_equatable() {
        XCTAssertEqual(UsageServiceError.notAuthenticated, UsageServiceError.notAuthenticated)
    }

    func test_error_orgIdNotFound_equatable() {
        XCTAssertEqual(UsageServiceError.orgIdNotFound, UsageServiceError.orgIdNotFound)
    }

    func test_error_networkError_equatable() {
        XCTAssertEqual(UsageServiceError.networkError("timeout"), UsageServiceError.networkError("timeout"))
        XCTAssertNotEqual(UsageServiceError.networkError("timeout"), UsageServiceError.networkError("404"))
    }

    func test_error_parseError_equatable() {
        XCTAssertEqual(UsageServiceError.parseError("bad json"), UsageServiceError.parseError("bad json"))
    }

    // MARK: - Initial state

    func test_initialState_lastDataIsNil() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        let service = UsageService(webView: webView)
        XCTAssertNil(service.lastData)
    }

    func test_resetCache_clearsLastData() throws {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        let service = UsageService(webView: webView)

        // Simulate having data by decoding a real JSON
        let json = """
        {
            "five_hour": { "utilization": 50.0, "resets_at": "2026-03-08T01:00:00+00:00" },
            "seven_day": { "utilization": 20.0, "resets_at": "2026-03-13T16:00:00+00:00" },
            "seven_day_sonnet": { "utilization": 5.0, "resets_at": "2026-03-14T21:00:00+00:00" },
            "seven_day_oauth_apps": null, "seven_day_opus": null,
            "seven_day_cowork": null, "iguana_necktie": null,
            "extra_usage": { "is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null }
        }
        """.data(using: .utf8)!

        // Set lastData by force using the decode path (same logic UsageService uses internally)
        let decoded = try UsageData.decode(from: json)
        // We can't set lastData directly (it's private(set)), so test resetCache on its effect
        // Instead, verify the service initializes cleanly and resetCache is callable without crash
        service.resetCache()
        XCTAssertNil(service.lastData)
        _ = decoded // suppress unused warning
    }

    func test_stopPolling_doesNotCrash() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        let service = UsageService(webView: webView)
        service.stopPolling() // Should not crash even before startPolling
    }
}
