import Testing
import Foundation

struct HTMLDecodingTests {
    @Test func dropsInlineTags() {
        #expect("<b>Bold</b> and <i>italic</i>".htmlDecoded == "Bold and italic")
    }

    @Test func dropsAttributedTags() {
        let html = "See <a href='https://example.org/x?a=1&amp;b=2' rel=\"nofollow\">this</a>."
        #expect(html.htmlDecoded == "See this.")
    }

    @Test func turnsBreaksIntoNewlines() {
        #expect("one<br />two".htmlDecoded == "one\ntwo")
        #expect("one<br>two".htmlDecoded == "one\ntwo")
        #expect("<p>one</p><p>two</p>".htmlDecoded == "one\ntwo")
    }

    @Test func collapsesRunsOfWhitespace() {
        #expect("a   \t b".htmlDecoded == "a b")
    }

    @Test func keepsBlankLines() {
        #expect("a<br /><br />b".htmlDecoded == "a\n\nb")
    }

    @Test func decodesNamedEntities() {
        #expect("Tom &amp; Jerry".htmlDecoded == "Tom & Jerry")
        #expect("&lt;not a tag&gt;".htmlDecoded == "<not a tag>")
        #expect("r&eacute;sum&eacute;".htmlDecoded == "résumé")
    }

    @Test func decodesNonBreakingSpace() {
        #expect("a&nbsp;b".htmlDecoded == "a\u{00A0}b")
    }

    @Test func decodesNumericEntities() {
        #expect("it&#39;s".htmlDecoded == "it's")
        #expect("it&#x27;s".htmlDecoded == "it's")
        #expect("&#8230;".htmlDecoded == "\u{2026}")
    }

    @Test func doesNotDoubleDecode() {
        #expect("&amp;#39;".htmlDecoded == "&#39;")
        #expect("&amp;lt;b&amp;gt;".htmlDecoded == "&lt;b&gt;")
    }

    @Test func leavesPlainTextUntouched() {
        let text = "Connell and Marianne grow up in the same small town."
        #expect(text.htmlDecoded == text)
    }

    @Test func handlesEmptyAndTagOnlyInput() {
        #expect("".htmlDecoded == "")
        #expect("<p></p>".htmlDecoded == "")
        #expect("   ".htmlDecoded == "")
    }

    @Test func toleratesUnclosedTag() {
        #expect("a < b".htmlDecoded == "a < b")
        #expect("5 < 7 and 9 > 3".htmlDecoded == "5 < 7 and 9 > 3")
    }

    @Test func decodesARealChaptarrOverview() {
        let html = """
        <p><b>'The literary phenomenon of the decade.' <i>Guardian</i> </b> <br /> \
        <b>'The book that defined a generation.' <i>Stylist</i> </b> <br /> \
        Connell and Marianne grow up in the same small town in the west of Ireland.</p><b> </b>
        """

        let text = html.htmlDecoded

        #expect(!text.contains("<"))
        #expect(!text.contains(">"))
        #expect(text.hasPrefix("'The literary phenomenon of the decade.' Guardian"))
        #expect(text.hasSuffix("in the west of Ireland."))
    }
}

struct SingleLiningTests {
    @Test func flattensNewlines() {
        #expect("a\nb".singleLined() == "a b")
        #expect("a\n\n\nb".singleLined() == "a b")
        #expect("a\r\nb".singleLined() == "a b")
    }

    @Test func collapsesSurroundingWhitespace() {
        #expect("a  \n  b".singleLined() == "a b")
        #expect("a \n b \n c".singleLined() == "a b c")
    }

    @Test func trimsEnds() {
        #expect("\n\na\n\n".singleLined() == "a")
    }

    @Test func leavesSingleLineTextUntouched() {
        let text = "Connell and Marianne grow up in the same small town."
        #expect(text.singleLined() == text)
    }

    @Test func keepsInteriorSpacingOtherwiseIntact() {
        #expect("a  b".singleLined() == "a  b")
    }
}
