import Foundation

enum DateFormatting {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return f
    }()

    /// Canonical ISO 8601 with second precision for server version matching.
    static func iso8601(from date: Date) -> String {
        let seconds = floor(date.timeIntervalSince1970)
        let rounded = Date(timeIntervalSince1970: seconds)
        return formatter.string(from: rounded)
    }

    static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}
