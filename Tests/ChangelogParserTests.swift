import Testing
import Foundation

// Validates `ChangelogParser.parse` in Ruddarr/Utilities/Changelog.swift, which
// turns the bundled `CHANGELOG.md` (Keep a Changelog format) into releases.
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
