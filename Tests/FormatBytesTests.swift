import Testing
import Foundation

// Exercises `formatBytes` in Ruddarr/Utilities/Formatters.swift. String assertions
// assume the en_US locale used by CI, since `ByteCountFormatter` output is localized.
struct FormatBytesTests {
    private func bytes(_ value: Double, _ power: Int) -> Int {
        Int(value * pow(1_024.0, Double(power)))
    }

    // MARK: - Binary (1024-based) unit selection

    @Test func formatsBinaryUnits() {
        #expect(formatBytes(0) == "Zero KB")
        #expect(formatBytes(512) == "512 bytes")
        #expect(formatBytes(1_024) == "1 KB")
        #expect(formatBytes(1_048_576) == "1 MB")
        #expect(formatBytes(1_073_741_824) == "1 GB")
    }

    // MARK: - Default precision (3 significant figures)

    @Test func defaultUsesThreeSignificantFigures() {
        #expect(formatBytes(bytes(100.5, 3)) == "101 GB")
        #expect(formatBytes(bytes(101.5, 4)) == "102 TB")
    }

    // MARK: - Adaptive sizing (`adaptive: true`)

    @Test func adaptiveKeepsExtraPrecision() {
        #expect(formatBytes(bytes(100.5, 3), adaptive: true) == "100.5 GB")
        #expect(formatBytes(bytes(101.5, 4), adaptive: true) == "101.5 TB")
    }

    @Test func adaptiveDiffersFromDefaultForPreciseLargeValues() {
        let value = bytes(100.5, 3) // 100.5 GiB
        #expect(formatBytes(value) == "101 GB")
        #expect(formatBytes(value, adaptive: true) == "100.5 GB")
        #expect(formatBytes(value) != formatBytes(value, adaptive: true))
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
        #expect(formatBytes(Float(1_024)) == formatBytes(1_024))
        #expect(formatBytes(Float(1_048_576)) == formatBytes(1_048_576))
    }
}
