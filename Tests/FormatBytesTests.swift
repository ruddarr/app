import Testing
import Foundation

// Exercises `formatBytes` in Ruddarr/Utilities/Formatters.swift. String assertions
// assume the en_US locale used by CI, since numeric/`ByteCountFormatter` output is localized.
struct FormatBytesTests {
    private func bytes(_ value: Double, _ power: Int) -> Int {
        Int(value * pow(1_024.0, Double(power)))
    }

    // MARK: - Binary (1024-based) unit selection

    @Test func formatsBinaryUnits() {
        #expect(formatBytes(0) == "0 bytes")
        #expect(formatBytes(512) == "512 bytes")
        #expect(formatBytes(1_024) == "1 KB")
        #expect(formatBytes(1_048_576) == "1 MB")
        #expect(formatBytes(1_073_741_824) == "1 GB")
    }

    // Disk-space values arrive as `Int64`; the generic overload accepts them without conversion.
    @Test func acceptsInt64() {
        #expect(formatBytes(Int64(1_073_741_824)) == "1 GB")
        #expect(formatBytes(Int64(bytes(477.76, 3))) == "478 GB")
    }

    // MARK: - Default precision (three significant figures)

    @Test func defaultUsesThreeSignificantFigures() {
        #expect(formatBytes(bytes(14.28, 3)) == "14.3 GB")
        #expect(formatBytes(bytes(1.419, 3)) == "1.42 GB")
        #expect(formatBytes(bytes(853.4, 2)) == "853 MB")
        #expect(formatBytes(bytes(477.76, 3)) == "478 GB")
        #expect(formatBytes(bytes(27.83, 4)) == "27.8 TB")
    }

    @Test func defaultOmitsTrailingZeros() {
        #expect(formatBytes(bytes(2, 3)) == "2 GB")
        #expect(formatBytes(bytes(56, 3)) == "56 GB")
    }

    // MARK: - Verbose precision (`verbose: true`)

    @Test func verboseKeepsExtraPrecision() {
        #expect(formatBytes(bytes(477.76, 3), verbose: true) == "477.76 GB")
        #expect(formatBytes(bytes(27.83, 4), verbose: true) == "27.83 TB")
        #expect(formatBytes(bytes(100.5, 3), verbose: true) == "100.5 GB")
    }

    @Test func verboseDiffersFromDefaultForPreciseLargeValues() {
        let value = bytes(477.76, 3) // 477.76 GiB
        #expect(formatBytes(value) == "478 GB")
        #expect(formatBytes(value, verbose: true) == "477.76 GB")
        #expect(formatBytes(value) != formatBytes(value, verbose: true))
    }

    // MARK: - Float overload (trap-safety on bad data)

    @Test func floatOverloadTreatsNonFiniteAndNegativeAsZero() {
        #expect(formatBytes(Float.nan) == formatBytes(0))
        #expect(formatBytes(Float.infinity) == formatBytes(0))
        #expect(formatBytes(-Float.infinity) == formatBytes(0))
        #expect(formatBytes(Float(-5)) == formatBytes(0))
    }

    @Test func floatOverloadClampsLargeFiniteValuesToMax() {
        #expect(formatBytes(Float.greatestFiniteMagnitude) == formatBytes(Int.max))
    }

    @Test func floatOverloadMatchesIntForFiniteValues() {
        #expect(formatBytes(Float(0)) == formatBytes(0))
        #expect(formatBytes(Float(1_024)) == formatBytes(1_024))
        #expect(formatBytes(Float(1_048_576)) == formatBytes(1_048_576))
    }

    @Test func floatOverloadForwardsVerboseFlag() {
        let value = bytes(477.76, 3) // 477.76 GiB
        #expect(formatBytes(Float(value), verbose: true) == formatBytes(value, verbose: true))
        #expect(formatBytes(Float(value), verbose: true) == "477.76 GB")
    }
}
