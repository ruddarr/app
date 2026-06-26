import Testing
import Foundation

// Validates the `JSONDecoder.DateDecodingStrategy.iso8601extended` migration in
// Ruddarr/Utilities/DateDecodingStrategy.swift, which replaced two shared
// `ISO8601DateFormatter` instances with the `Sendable` `Date.ISO8601FormatStyle`.
// These tests pin the parsing behavior, prove the new path matches the old one,
// and ensure `withFractionalSeconds` is still honored.
struct DateDecodingStrategyTests {
    /// The pre-migration implementation (ISO8601DateFormatter), kept here as a
    /// reference oracle to compare against.
    private func legacy(_ string: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return plain.date(from: string) ?? fractional.date(from: string)
    }

    /// Exercises the production `iso8601extended` decoding strategy.
    private func current(_ string: String) -> Date? {
        struct Wrapper: Decodable { let date: Date }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601extended

        let json = Data(#"{"date":"\#(string)"}"#.utf8)
        return try? decoder.decode(Wrapper.self, from: json).date
    }

    private let validDates = [
        "2024-01-15T10:30:00Z",
        "2024-01-15T10:30:00+02:00",
        "2024-01-15T10:30:00-05:00",
        "2024-12-31T23:59:59Z",
        "0001-01-01T00:00:00Z",          // Radarr/Sonarr "no date" sentinel
        "2024-01-15T10:30:00.123Z",      // fractional, Z
        "2024-01-15T10:30:00.5+02:00",   // fractional, offset
        "2024-12-31T23:59:59.999Z",      // fractional, milliseconds
    ]

    @Test func newImplementationMatchesLegacy() {
        for string in validDates {
            let old = legacy(string)
            let new = current(string)

            #expect(old != nil, "legacy failed to parse \(string)")
            #expect(new != nil, "current failed to parse \(string)")

            if let old, let new {
                // A 1ms tolerance: the new path keeps sub-millisecond precision that
                // ISO8601DateFormatter truncates, and Double carries ~1e-7s representation
                // noise — both far below anything Ruddarr displays or sorts on.
                let delta = abs(old.timeIntervalSinceReferenceDate - new.timeIntervalSinceReferenceDate)
                #expect(delta < 0.001, "mismatch for \(string): old=\(old) new=\(new)")
            }
        }
    }

    @Test func preservesFractionalSeconds() {
        // The reason the second formatter existed: a `.123` fraction must survive.
        guard let withFraction = current("2024-01-15T10:30:00.123Z"),
              let whole = current("2024-01-15T10:30:00Z")
        else {
            Issue.record("Failed to parse fractional-second date")
            return
        }

        let fraction = withFraction.timeIntervalSince(whole)
        #expect(abs(fraction - 0.123) < 0.0005, "expected ~0.123s fractional offset, got \(fraction)")
    }

    @Test func parsesWholeSecondsToExpectedInstant() {
        // 2024-01-15T10:30:00Z is 1_705_314_600 seconds since 1970.
        let date = current("2024-01-15T10:30:00Z")
        #expect(date != nil)
        #expect(abs((date?.timeIntervalSince1970 ?? 0) - 1_705_314_600) < 0.001)
    }

    @Test func respectsTimeZoneOffsets() {
        // Same instant expressed in UTC and +02:00 must decode identically.
        let utc = current("2024-01-15T10:30:00Z")
        let offset = current("2024-01-15T12:30:00+02:00")

        #expect(utc != nil && offset != nil)
        if let utc, let offset {
            #expect(abs(utc.timeIntervalSince1970 - offset.timeIntervalSince1970) < 0.001)
        }
    }

    @Test func rejectsInvalidStrings() {
        #expect(current("") == nil)
        #expect(current("not a date") == nil)
        #expect(current("2024-13-45T99:99:99Z") == nil)
    }

    @Test func decodesThroughJSONDecoderStrategy() {
        // Exercises the strategy the way the API layer uses it.
        struct Wrapper: Decodable { let date: Date }
        let json = Data(#"{"date":"2024-01-15T10:30:00.123Z"}"#.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601extended

        let decoded = try? decoder.decode(Wrapper.self, from: json)
        #expect(decoded != nil)
        #expect(abs((decoded?.date.timeIntervalSince1970 ?? 0) - 1_705_314_600.123) < 0.0005)
    }
}
