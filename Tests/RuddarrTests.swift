import Testing
import Foundation

struct RuddarrTests {
    @Test func resolveLocalizedStringWithArgs() {
        let format = "%@ (S%@ E%@)"
        let args: [Any] = ["Breaking Bad", "1", "23"]
        let result = String(format: format, arguments: args.map { "\($0)" as NSString })
        #expect(result == "Breaking Bad (S1 E23)")
    }

    @Test func resolveLocalizedStringWithIntArgs() {
        let format = "%@ (S%@ E%@)"
        let args: [Any] = ["Breaking Bad", 2, 45]
        let result = String(format: format, arguments: args.map { "\($0)" as NSString })
        #expect(result == "Breaking Bad (S2 E45)")
    }

    @Test func resolveLocalizedStringWithNoArgs() {
        let format = "Episode Downloaded"
        let result = String(format: format, arguments: [])
        #expect(result == "Episode Downloaded")
    }

    @Test func resolveLocalizedStringFallback() {
        // When key equals the NSLocalizedString result (key not found), use fallback
        let key = "NONEXISTENT_KEY"
        let format = NSLocalizedString(key, comment: "")
        let fallback = "Fallback Title"

        let result = format == key ? fallback : format
        #expect(result == "Fallback Title")
    }

    @Test func formatCustomScoreIsSigned() {
        // Mirrors formatCustomScore() in Movie.swift. The "%+d" flag forces a
        // single leading sign, fixing the previous "%@%d" approach that
        // double-signed negatives (e.g. "--5000" instead of "-5000").
        #expect(String(format: "%+d", 500) == "+500")
        #expect(String(format: "%+d", 0) == "+0")
        #expect(String(format: "%+d", -5000) == "-5000")
    }
}

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

// Validates `ChangelogParser.parse` in Ruddarr/Views/Settings/Changelog.swift,
// which turns the bundled `CHANGELOG.md` (Keep a Changelog format) into releases.
// Focus: free-text copy that appears after a version heading but before the
// `### Added`/etc. groups (parsed into `ChangelogRelease.note`).
struct ChangelogParserTests {
    private func parse(_ text: String) -> [ChangelogRelease] {
        ChangelogParser.parse(text)
    }

    private func release(_ version: String, in releases: [ChangelogRelease]) -> ChangelogRelease? {
        releases.first { $0.version == version }
    }

    // MARK: Version heading & date

    @Test func parsesVersionAndDate() {
        let releases = parse("""
        ## 1.2.0 - 2024-09-16

        ### Added
        - Spotlight integration
        """)

        #expect(releases.count == 1)
        #expect(releases.first?.version == "1.2.0")
        #expect(releases.first?.rawDate == "2024-09-16")
        #expect(releases.first?.date != nil)
    }

    @Test func parsesUnreleasedHeadingWithoutDate() {
        let releases = parse("""
        ## Unreleased

        ### Added
        - Upcoming feature
        """)

        #expect(releases.first?.version == "Unreleased")
        #expect(releases.first?.date == nil)
        #expect(releases.first?.rawDate == "")
        #expect(releases.first?.sections.first?.bullets == ["Upcoming feature"])
    }

    @Test func parsesPopulatedUnreleasedAboveDatedReleases() {
        // The canonical top-of-changelog layout: an "Unreleased" section with
        // content sitting above the most recent dated release.
        let releases = parse("""
        ## Unreleased

        ### Added
        - Brand new thing

        ## 1.0.0 - 2024-01-01

        ### Fixed
        - Old bug
        """)

        #expect(releases.count == 2)

        let unreleased = release("Unreleased", in: releases)
        #expect(unreleased?.date == nil)
        #expect(unreleased?.sections.first?.kind == .added)
        #expect(unreleased?.sections.first?.bullets == ["Brand new thing"])

        let dated = release("1.0.0", in: releases)
        #expect(dated?.date != nil)
        #expect(dated?.sections.first?.kind == .fixed)
    }

    // MARK: Sections & bullets

    @Test func parsesSectionsInOrderWithStrippedBullets() {
        let releases = parse("""
        ## 1.0.0 - 2024-01-01

        ### Added
        - First
        - Second

        ### Fixed
        - A crash
        """)

        let section = release("1.0.0", in: releases)?.sections
        #expect(section?.count == 2)
        #expect(section?.first?.kind == .added)
        #expect(section?.first?.bullets == ["First", "Second"])
        #expect(section?.last?.kind == .fixed)
        #expect(section?.last?.bullets == ["A crash"])
    }

    @Test func ignoresUnknownSectionHeadings() {
        // "### Notes" is not a ChangelogKind, so it produces no section.
        let releases = parse("""
        ## 1.0.0 - 2024-01-01

        ### Notes
        - not a known kind

        ### Added
        - real item
        """)

        #expect(releases.first?.sections.count == 1)
        #expect(releases.first?.sections.first?.kind == .added)
        #expect(releases.first?.sections.first?.bullets == ["real item"])
    }

    // MARK: Copy after the version heading, before the sections (the note)

    @Test func capturesIntroParagraphBeforeSections() {
        let releases = parse("""
        ## 2.0.0 - 2024-06-01

        This release focuses on performance.

        ### Added
        - New engine
        """)

        #expect(releases.first?.note == "This release focuses on performance.")
        #expect(releases.first?.sections.first?.bullets == ["New engine"])
    }

    @Test func capturesMultiLineIntroParagraph() {
        let releases = parse("""
        ## 2.0.0 - 2024-06-01

        First line of copy.
        Second line of copy.

        ### Fixed
        - A bug
        """)

        #expect(releases.first?.note == "First line of copy.\nSecond line of copy.")
    }

    @Test func keepsReleaseWithIntroButNoSections() {
        // The empty-release guard must still keep a release that has only copy.
        let releases = parse("""
        ## 3.0.0 - 2024-07-01

        Just an announcement, no itemized changes.
        """)

        #expect(releases.count == 1)
        #expect(releases.first?.note == "Just an announcement, no itemized changes.")
        #expect(releases.first?.sections.isEmpty == true)
    }

    @Test func introCopyDoesNotLeakIntoBulletsOrNextRelease() {
        let releases = parse("""
        ## 2.0.0 - 2024-06-01

        Intro for 2.0.0.

        ### Added
        - Thing

        ## 1.0.0 - 2024-01-01

        ### Added
        - Initial
        """)

        #expect(releases.count == 2)

        let new = release("2.0.0", in: releases)
        #expect(new?.note == "Intro for 2.0.0.")
        #expect(new?.sections.first?.bullets == ["Thing"])

        let old = release("1.0.0", in: releases)
        #expect(old?.note == nil)
        #expect(old?.sections.first?.bullets == ["Initial"])
    }

    @Test func doesNotTreatFilePreambleAsAReleaseOrNote() {
        let releases = parse("""
        # Changelog

        All notable changes to Ruddarr are documented in this file.

        ## 1.0.0 - 2024-01-01

        ### Added
        - Initial
        """)

        #expect(releases.count == 1)
        #expect(releases.first?.version == "1.0.0")
        #expect(releases.first?.note == nil)
    }

    // MARK: Empty / whitespace handling

    @Test func skipsEmptyReleaseHeading() {
        let releases = parse("""
        ## Unreleased

        ## 1.0.0 - 2024-01-01

        ### Added
        - Initial
        """)

        #expect(releases.count == 1)
        #expect(releases.first?.version == "1.0.0")
    }

    @Test func returnsEmptyForBlankInput() {
        #expect(parse("").isEmpty)
        #expect(parse("\n\n   \n").isEmpty)
    }
}
