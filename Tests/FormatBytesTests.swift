import Testing
import Foundation

// Exercises `formatBytes` in Ruddarr/Utilities/Formatters.swift. String assertions
// assume the en_US locale used by CI, since `ByteCountFormatter` output is localized.
struct FormatBytesTests {
    // MARK: - Decimal (1000-based) sizing

    @Test func formatsSmallSizesAdaptively() {
        #expect(formatBytes(0) == "Zero KB")
        #expect(formatBytes(500) == "500 bytes")
        #expect(formatBytes(1_000) == "1 KB")
        #expect(formatBytes(1_000_000) == "1 MB")
    }

    @Test func formatsLargeSizesWithThreeSignificantFigures() {
        #expect(formatBytes(1_000_000_000) == "1 GB")
        #expect(formatBytes(100_500_000_000) == "101 GB")     // 100.5 GB
        #expect(formatBytes(101_500_000_000_000) == "102 TB") // 101.5 TB
    }

    @Test func roundedUpValueRollsOverToNextUnit() {
        // 999.9 GB rounds to 1,000 GB, which decimal sizing rolls over to 1 TB.
        #expect(formatBytes(999_900_000_000) == "1 TB")
    }

    // MARK: - Float overload (trap-safety on bad data)

    @Test func floatOverloadTreatsNonFiniteAndNegativeAsZero() {
        #expect(formatBytes(Float.nan) == formatBytes(0))
        #expect(formatBytes(Float.infinity) == formatBytes(0))
        #expect(formatBytes(-Float.infinity) == formatBytes(0))
        #expect(formatBytes(Float(-5)) == formatBytes(0))
    }

    @Test func floatOverloadClampsLargeFiniteValuesToMax() {
        #expect(formatBytes(Float.greatestFiniteMagnitude) == formatBytes(.max))
    }

    @Test func floatOverloadMatchesIntForFiniteValues() {
        #expect(formatBytes(Float(0)) == formatBytes(0))
        #expect(formatBytes(Float(1_000)) == formatBytes(1_000))
        #expect(formatBytes(Float(1_000_000)) == formatBytes(1_000_000))
    }
}
