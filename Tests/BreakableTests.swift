import Testing

// Validates `String.breakable(minimumTail:)` in Ruddarr/Utilities/Helpers.swift,
// which inserts zero-width spaces after dots so release titles can wrap, and
// optionally glues the tail with non-breaking spaces so the last line of a
// wrapped title keeps at least `minimumTail` characters (no "2.0" orphans).
struct BreakableTests {
    @Test func insertsBreaksAfterDots() {
        #expect("a.b.c".breakable() == "a.\u{200B}b.\u{200B}c")
    }

    @Test func leavesDotlessStringsAlone() {
        #expect("Some Title".breakable() == "Some Title")
    }

    @Test func gluesSpacedTailToMinimumLength() {
        let title = "Tenet 2020 Bonus Disc 1080p Blu-ray AVC DD 2.0"

        #expect(
            title.breakable(minimumTail: 10) ==
            "Tenet 2020 Bonus Disc 1080p Blu-ray AVC\u{A0}DD\u{A0}2.0"
        )
    }

    @Test func gluedTailKeepsDotsUnbreakable() {
        let glued = "Show Name 1080p AVC DD 2.0".breakable(minimumTail: 10)

        #expect(glued == "Show Name 1080p AVC\u{A0}DD\u{A0}2.0")
        #expect(!glued.contains("\u{200B}"))
    }

    @Test func gluesDottedTailAndBreaksHead() {
        let title = "Show.S01E01.WEB.MA.5.1-GROUP"

        #expect(
            title.breakable(minimumTail: 10) ==
            "Show.\u{200B}S01E01.\u{200B}WEB.\u{200B}MA.5.1-\u{2060}GROUP"
        )
    }

    @Test func gluedTailSuppressesBraceAndSlashBreaks() {
        let glued = "Show Name 1080p x265{h}/x264".breakable(minimumTail: 10)

        #expect(glued == "Show Name 1080p x265{h}\u{2060}/\u{2060}x264")
    }

    @Test func gluedTailKeepsBracketTagsTogether() {
        let glued = "Show Name 2160p x265[Tag][Two]".breakable(minimumTail: 10)

        #expect(glued == "Show Name 2160p x265[Tag]\u{2060}[Two]")
    }

    @Test func fallsBackWhenNoBreakLeavesEnoughTail() {
        #expect("DD 2.0".breakable(minimumTail: 10) == "DD 2.\u{200B}0")
    }

    @Test func zeroMinimumMatchesPlainBreakable() {
        let title = "Show.S01E01.WEB-GROUP"

        #expect(title.breakable(minimumTail: 0) == title.breakable())
    }
}
