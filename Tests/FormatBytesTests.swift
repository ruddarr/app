import Testing
import Foundation

// Validates `formatBytes` in Ruddarr/Utilities/FormatBytes.swift, which renders
// a (binary, 1024-based) byte count with three significant figures so the
// precision scales with magnitude: 1.12 TB, 10.2 TB, 101 TB.
struct FormatBytesTests {
    private func bytes(_ value: Double, _ power: Int) -> Int {
        Int(value * pow(1_024.0, Double(power)))
    }

    @Test func formatsTerabytesWithThreeSignificantFigures() {
        #expect(formatBytes(bytes(1.12, 4)) == "1.12 TB")
        #expect(formatBytes(bytes(10.2, 4)) == "10.2 TB")
        #expect(formatBytes(bytes(101, 4)) == "101 TB")
    }

    @Test func formatsGigabytesWithThreeSignificantFigures() {
        #expect(formatBytes(bytes(1.22, 3)) == "1.22 GB")
        #expect(formatBytes(bytes(22.1, 3)) == "22.1 GB")
        #expect(formatBytes(bytes(502, 3)) == "502 GB")
    }

    @Test func formatsMegabytesWithThreeSignificantFigures() {
        #expect(formatBytes(bytes(1.34, 2)) == "1.34 MB")
        #expect(formatBytes(bytes(10.2, 2)) == "10.2 MB")
        #expect(formatBytes(bytes(100, 2)) == "100 MB")
    }

    @Test func padsTrailingZerosToKeepThreeSignificantFigures() {
        #expect(formatBytes(bytes(5, 3)) == "5.00 GB")
        #expect(formatBytes(bytes(1.2, 4)) == "1.20 TB")
    }

    @Test func roundsUpAcrossTierBoundaries() {
        // 9.999 GB rounds to three sig figs as 10.0 GB (one decimal), not 10.00.
        #expect(formatBytes(bytes(9.999, 3)) == "10.0 GB")
    }

    @Test func formatsSmallAndZeroValues() {
        #expect(formatBytes(0) == "0 KB")
        #expect(formatBytes(512) == "512 bytes")
        #expect(formatBytes(bytes(1.5, 1)) == "1.50 KB")
    }

    @Test func selectsTheLargestFittingUnit() {
        #expect(formatBytes(1_023) == "1,023 bytes")
        #expect(formatBytes(1_024) == "1.00 KB")
        #expect(formatBytes(1_048_576) == "1.00 MB")
    }
}
