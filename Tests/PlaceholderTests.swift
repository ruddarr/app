import Testing
import Foundation

// Validates `String.placeholders` in Ruddarr/Utilities/Placeholder.swift, the
// memory-safe replacement for `String(format:)` used for localized string templates (the
// search overlays, instance notifications, media-history event labels, etc.). Where the
// behaviour is defined, it is cross-checked against `String(format:)` itself as an oracle.
struct PlaceholderTests {
    /// `String(format:)` reference oracle (the API these strings used before the migration).
    private func legacy(_ format: String, _ arguments: [String]) -> String {
        String(format: format, arguments: arguments.map { $0 as NSString })
    }

    // MARK: - Sequential %@

    @Test func substitutesSingleSequentialPlaceholder() {
        #expect("Hello, %@!".placeholders("world") == "Hello, world!")
    }

    @Test func substitutesMultipleSequentialPlaceholdersInOrder() {
        #expect("%@ (%@)".placeholders("Title", "2024") == "Title (2024)")
    }

    @Test func substitutesAdjacentPlaceholders() {
        #expect("%@%@".placeholders("a", "b") == "ab")
    }

    @Test func acceptsArrayAndVariadicForms() {
        #expect("%@ / %@".placeholders("a", "b") == "%@ / %@".placeholders(["a", "b"]))
    }

    // MARK: - Positional %n$@

    @Test func substitutesPositionalPlaceholders() {
        #expect("%1$@ from %2$@ to %3$@".placeholders("M", "H", "q") == "M from H to q")
    }

    @Test func positionalPlaceholdersCanReorderArguments() {
        #expect("%2$@ %1$@".placeholders("first", "second") == "second first")
    }

    @Test func positionalPlaceholderCanRepeatAnArgument() {
        #expect("%1$@ %1$@".placeholders("echo") == "echo echo")
    }

    // MARK: - Escaping & verbatim handling

    @Test func doublePercentBecomesLiteralPercent() {
        #expect("100%% done".placeholders() == "100% done")
    }

    @Test func returnsInputUnchangedWhenNoPlaceholders() {
        #expect("nothing to replace".placeholders("unused") == "nothing to replace")
    }

    @Test func substitutesIntegerSlots() {
        // %d and %i are substitution slots too; arguments can be passed as Int directly.
        #expect("%d items".placeholders(5) == "5 items")
        #expect("%i of %i".placeholders(3, 10) == "3 of 10")
        #expect("%@ has %d".placeholders("Box", 5) == "Box has 5")
        #expect("%2$d-%1$d".placeholders(1, 2) == "2-1")
    }

    @Test func substitutesLongLongSlots() {
        // %lld / %lli (printf's `long long`) behave like %d / %i — Swift's String Catalog emits
        // %lld for Int counts, so the helper accepts them (sequential, positional, and mixed).
        #expect("%lld items".placeholders(5) == "5 items")
        #expect("%lli of %lld".placeholders(3, 10) == "3 of 10")
        #expect("%@ has %lld".placeholders("Box", Int64(5)) == "Box has 5")
        #expect("%2$lld-%1$lld".placeholders(1, 2) == "2-1")
        // genuinely 64-bit values round-trip through `.description`
        #expect("%lld".placeholders(Int64.max) == "\(Int64.max)")
        #expect("%lld".placeholders(Int64.min) == "\(Int64.min)")
    }

    @Test func acceptsMixedConvertibleArgumentTypes() {
        // Arguments may be any LosslessStringConvertible — Int and String can mix freely.
        #expect("%@: %d of %d".placeholders("Episodes", 3, 10) == "Episodes: 3 of 10")
    }

    @Test func leavesWidthAndPrecisionSpecifiersVerbatim() {
        // Width/precision specifiers are not handled — they stay literal.
        #expect("%.1f".placeholders("5") == "%.1f")
        #expect("%02d".placeholders("5") == "%02d")
        #expect("%x".placeholders("5") == "%x")
    }

    @Test func leavesUnsupportedLengthModifiersVerbatim() {
        // Only "ll" + d/i is recognized; other length/conversion combinations stay literal.
        #expect("%ld".placeholders(5) == "%ld")     // single 'l' (long, not long long)
        #expect("%llx".placeholders(5) == "%llx")   // long long, but hex conversion
        #expect("%lf".placeholders(5) == "%lf")     // 'l' then 'f'
        #expect("%ll".placeholders(5) == "%ll")     // truncated — no conversion follows
    }

    @Test func keepsTrailingPercentVerbatim() {
        #expect("50%".placeholders() == "50%")
        #expect("ends with %".placeholders() == "ends with %")
    }

    // MARK: - Argument count edge cases

    @Test func ignoresExtraArguments() {
        #expect("%@".placeholders("used", "extra") == "used")
    }

    @Test func missingArgumentsAreDroppedWithoutCrashing() {
        #expect("%@ and %@".placeholders("only") == "only and ")
        #expect("%2$@".placeholders() == "")
    }

    // MARK: - Unicode

    @Test func preservesUnicodeInLiteralText() {
        #expect("café %@ 🎬".placeholders("X") == "café X 🎬")
    }

    @Test func substitutesUnicodeArguments() {
        #expect("%@ + %@".placeholders("α", "🎬") == "α + 🎬")
    }

    // MARK: - Cross-check against String(format:) oracle

    @Test(arguments: [
        ("%@", ["x"]),
        ("%@ (%@)", ["Breaking Bad", "S1"]),
        ("%1$@ grabbed from %2$@ and sent to %3$@.", ["Movie", "HDBits", "qBittorrent"]),
        ("%2$@ %1$@", ["a", "b"]),
        ("Connect a %@ instance under %@.", ["Radarr", "[Settings](#view)"]),
        ("100%% done", []),
        ("café %@ 🎬", ["X"]),
    ])
    func matchesStringFormatOracle(_ testCase: (format: String, arguments: [String])) {
        #expect(
            testCase.format.placeholders(testCase.arguments) == legacy(testCase.format, testCase.arguments),
            "mismatch for \(testCase.format.debugDescription)"
        )
    }

    // MARK: - Real call-site templates

    @Test func handlesActualLocalizedTemplates() {
        #expect(
            "Check the spelling or try [adding the movie](%@).".placeholders("#view")
                == "Check the spelling or try [adding the movie](#view)."
        )
        #expect(
            "Notifications require a subscription to %@.".placeholders("[Ruddarr+](#link)")
                == "Notifications require a subscription to [Ruddarr+](#link)."
        )
    }
}
