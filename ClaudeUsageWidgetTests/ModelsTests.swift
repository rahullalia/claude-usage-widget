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

    // MARK: - Reset time formatting

    func test_formatResetsAt_date() {
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
        let futureDate = Date().addingTimeInterval(2520) // 42 minutes from now
        let stat = UsageStat(percentUsed: 0.5, resetsAt: futureDate)
        let display = stat.resetsInDisplay
        XCTAssertTrue(display.contains("m") || display.contains("h"), "Expected time display, got: \(display)")
    }

    // MARK: - JSON decoding

    func test_usageData_decodesFromRealAPIShape() throws {
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
