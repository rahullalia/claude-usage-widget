import Foundation

// MARK: - RingColorState

public enum RingColorState: Equatable {
    case normal    // 0–59%
    case amber     // 60–84%
    case critical  // 85–100%

    public static func from(percent: Double) -> RingColorState {
        switch percent {
        case ..<0.60:
            return .normal
        case 0.60..<0.85:
            return .amber
        default:
            return .critical
        }
    }
}

// MARK: - UsageStat

public struct UsageStat {
    public let percentUsed: Double   // 0.0 to 1.0
    public let resetsAt: Date?

    public init(percentUsed: Double, resetsAt: Date?) {
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
    }

    /// "resets in 42m" or "resets in 1h 12m" — returns "–" if nil or past
    public var resetsInDisplay: String {
        guard let date = resetsAt else { return "–" }
        let remaining = date.timeIntervalSinceNow
        guard remaining > 0 else { return "–" }

        let totalMinutes = Int(remaining / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "resets in \(hours)h \(minutes)m"
        } else {
            return "resets in \(minutes)m"
        }
    }

    /// "Fri 9:00 AM" — returns nil if resetsAt is nil
    public var resetsAtDisplay: String? {
        guard let date = resetsAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - UsageData

public struct UsageData {
    public let currentSession: UsageStat
    public let weeklyAllModels: UsageStat
    public let weeklySonnetOnly: UsageStat
    public var lastUpdated: Date

    public init(
        currentSession: UsageStat,
        weeklyAllModels: UsageStat,
        weeklySonnetOnly: UsageStat,
        lastUpdated: Date = Date()
    ) {
        self.currentSession = currentSession
        self.weeklyAllModels = weeklyAllModels
        self.weeklySonnetOnly = weeklySonnetOnly
        self.lastUpdated = lastUpdated
    }

    /// Highest usage % across all three metrics
    public var ringValue: Double {
        max(currentSession.percentUsed, weeklyAllModels.percentUsed, weeklySonnetOnly.percentUsed)
    }

    public var ringColorState: RingColorState {
        .from(percent: ringValue)
    }
}

// MARK: - JSON Decoding

private struct RawUsageStat: Codable {
    let utilization: Double
    let resets_at: Date
}

private struct RawUsageResponse: Codable {
    let five_hour: RawUsageStat
    let seven_day: RawUsageStat
    let seven_day_sonnet: RawUsageStat?
}

extension UsageData {
    /// Decode from raw API JSON — handles fractional-second ISO8601 dates
    public static func decode(from data: Data) throws -> UsageData {
        let decoder = JSONDecoder()

        // Try fractional seconds first, then fall back to whole seconds
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = fractionalFormatter.date(from: string) {
                return date
            }
            if let date = plainFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(string)"
            )
        }

        let raw = try decoder.decode(RawUsageResponse.self, from: data)

        let currentSession = UsageStat(
            percentUsed: raw.five_hour.utilization / 100.0,
            resetsAt: raw.five_hour.resets_at
        )
        let weeklyAllModels = UsageStat(
            percentUsed: raw.seven_day.utilization / 100.0,
            resetsAt: raw.seven_day.resets_at
        )
        let weeklySonnetOnly = UsageStat(
            percentUsed: (raw.seven_day_sonnet?.utilization ?? 0.0) / 100.0,
            resetsAt: raw.seven_day_sonnet?.resets_at
        )

        return UsageData(
            currentSession: currentSession,
            weeklyAllModels: weeklyAllModels,
            weeklySonnetOnly: weeklySonnetOnly,
            lastUpdated: Date()
        )
    }
}
