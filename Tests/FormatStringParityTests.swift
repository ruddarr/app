import Testing
import Foundation

// Proves the Swift-6 `String(format:)` migrations on this branch are behavior-preserving:
// each new, safe formatting expression renders byte-for-byte identically to the C
// `printf`-style original it replaced, across the domain the production value can take.
// Like `HexEncodingTests`, every suite keeps the pre-change expression as a reference
// oracle (`legacy`) and asserts the shipping expression (`current`) matches it.

// MARK: - MovieRatings percent formatting

// Covers the `.percentageRating` format style, used by MovieRatings.swift `rotten`/`tmdb`
// and SeriesDetails+Overview.swift, where
//   Text(String(format: "%.0f%%", rating))
// became
//   Text(rating.formatted(.percentageRating))
//
// `rating` is a `Float` (`MovieRating.value`). The helper formats the number and appends a
// literal "%", so it stays byte-for-byte identical to the printf original. The non-obvious
// fact pinned here is that BOTH expressions round to whole percent using round-half-to-even:
// C `%.0f` uses the IEEE default mode, and `FloatingPointFormatStyle`'s default rounding rule
// is likewise `.toNearestOrEven` (not `.toNearestOrAwayFromZero`). This is also why the helper
// avoids `.percent`, whose ÷100 round-trip would break that tie behavior. String comparisons
// assume the Latin-digit en_US locale used by CI, since `FloatingPointFormatStyle` localizes
// digits while `String(format:)` does not — see `FormatBytesTests`.
struct MovieRatingFormatParityTests {
    /// Pre-change expression from `rotten` / `tmdb`, kept as a reference oracle.
    private func legacy(_ rating: Float) -> String {
        String(format: "%.0f%%", rating)
    }

    /// The shipping helper under test.
    private func current(_ rating: Float) -> String {
        rating.formatted(.percentageRating)
    }

    // Rotten Tomatoes / Metacritic supply integer percent scores 0...100.
    @Test func matchesOverIntegerScoreDomain() {
        for score in 0...100 {
            let rating = Float(score)
            #expect(current(rating) == legacy(rating), "mismatch at \(score)")
        }
    }

    // TMDB stores a 0.0...10.0 score; the view renders `rating * 10` as a percent, so the
    // formatter sees the float-multiply result (e.g. 7.842 * 10 == 78.42), not a clean int.
    @Test func matchesTmdbScaledScores() {
        for tenths in 0...100 {
            let value = (Float(tenths) / 10) * 10
            #expect(current(value) == legacy(value), "mismatch at \(value)")
        }

        for tmdb: Float in [6.2, 7.842, 7.85, 8.0, 8.456, 9.99] {
            let value = tmdb * 10
            #expect(current(value) == legacy(value), "mismatch at \(value)")
        }
    }

    // The interesting case: exactly-.5 inputs are ties. Both expressions resolve them to
    // the nearest even integer, so they agree — this is what keeps the migration safe, and
    // what a `.percent`-based helper would silently break (78.5 → 79 instead of 78).
    @Test func roundsHalvesToEvenLikePrintf() {
        let ties: [(Float, String)] = [
            (0.5, "0%"), (1.5, "2%"), (2.5, "2%"), (3.5, "4%"),
            (4.5, "4%"), (50.5, "50%"), (78.5, "78%"), (87.5, "88%"),
        ]

        for (rating, expected) in ties {
            #expect(current(rating) == expected, "current(\(rating))")
            #expect(legacy(rating) == expected, "legacy(\(rating))")
        }
    }

    // -50.00 ... 200.00 in 0.01 steps — far beyond the realistic 0...100 range, including
    // negatives, to catch any rounding boundary where the two could drift apart.
    @Test func matchesAcrossDenseFiniteSweep() {
        var firstMismatch: Float?

        for hundredths in -5_000...20_000 {
            let rating = Float(hundredths) / 100
            if current(rating) != legacy(rating) { firstMismatch = rating; break }
        }

        #expect(firstMismatch == nil, "first mismatch at \(firstMismatch ?? 0)")
    }

    // The sole divergence is non-finite input: `printf` prints lowercase ASCII
    // ("nan"/"inf"), `FloatingPointFormatStyle` prints "NaN"/"∞". A `MovieRating.value`
    // is always finite, so this is unreachable in production — pinning it documents the
    // exact boundary of the equivalence proven above.
    @Test func divergesOnlyOnNonFiniteInput() {
        #expect(current(.nan) != legacy(.nan))
        #expect(current(.infinity) != legacy(.infinity))
        #expect(current(-.infinity) != legacy(-.infinity))
    }
}

// MARK: - MovieRatings one-decimal formatting

// Covers MovieRatings.swift `imdb`, where
//   Text(String(format: "%.1f", rating))
// became
//   Text(rating.formatted(.decimal(1)))
//
// Same `Float` rating, but rounded to ONE decimal — a finer boundary than the percent
// suites above (ties fall at X.X5, not X.5), so its parity does not follow from them and
// is pinned separately. Both expressions still round halves to even, and the same en_US
// /Latin-digit locale assumption applies. (The non-finite divergence is identical to the
// percent suite and is documented there.)
struct MovieRatingOneDecimalParityTests {
    /// Pre-change expression from `imdb`, kept as a reference oracle.
    private func legacy(_ rating: Float) -> String {
        String(format: "%.1f", rating)
    }

    /// The shipping expression under test.
    private func current(_ rating: Float) -> String {
        rating.formatted(.decimal(1))
    }

    // IMDb supplies a 0.0...10.0 score, normally to one decimal place.
    @Test func matchesOverImdbDomain() {
        for tenths in 0...100 {
            let rating = Float(tenths) / 10
            #expect(current(rating) == legacy(rating), "mismatch at \(rating)")
        }
    }

    // Exactly-representable X.25 / X.75 inputs are true first-decimal ties; both
    // expressions resolve them to the nearest even tenth, so they stay in agreement.
    @Test func roundsFirstDecimalHalvesToEven() {
        let ties: [(Float, String)] = [
            (0.25, "0.2"), (0.75, "0.8"), (2.25, "2.2"), (2.75, "2.8"),
            (6.25, "6.2"), (6.75, "6.8"), (8.25, "8.2"), (8.75, "8.8"),
        ]

        for (rating, expected) in ties {
            #expect(current(rating) == expected, "current(\(rating))")
            #expect(legacy(rating) == expected, "legacy(\(rating))")
        }
    }

    // -20.000 ... 20.000 in 0.001 steps — beyond the realistic 0...10 range, including
    // negatives, to catch any one-decimal rounding boundary where the two could drift.
    @Test func matchesAcrossDenseFiniteSweep() {
        var firstMismatch: Float?

        for thousandths in -20_000...20_000 {
            let rating = Float(thousandths) / 1_000
            if current(rating) != legacy(rating) { firstMismatch = rating; break }
        }

        #expect(firstMismatch == nil, "first mismatch at \(firstMismatch ?? 0)")
    }
}

// MARK: - Spotlight checksum hex formatting

// Covers Spotlight.swift `calculateChecksum`, where
//   return String(format: "%08x", checksum)
// became
//   let hex = String(checksum, radix: 16)
//   return String(repeating: "0", count: max(0, 8 - hex.count)) + hex
//
// `checksum` is a zlib `crc32` result: typed `UInt` (`uLong`) but always within the
// CRC-32 range 0...0xFFFFFFFF. Over that whole range the manual zero-padded radix-16
// string equals `%08x` exactly. The replacement also removes a latent bug: `%x` consumes
// a 32-bit `unsigned int`, so the old form would silently truncate any value above
// 0xFFFFFFFF, whereas `String(_:radix:)` cannot.
struct ChecksumHexFormatParityTests {
    /// Pre-change expression from `calculateChecksum`, kept as a reference oracle.
    private func legacy(_ checksum: UInt) -> String {
        String(format: "%08x", checksum)
    }

    /// The shipping expression under test.
    private func current(_ checksum: UInt) -> String {
        let hex = String(checksum, radix: 16)
        return String(repeating: "0", count: max(0, 8 - hex.count)) + hex
    }

    @Test func matchesRepresentativeValues() {
        let expectations: [(UInt, String)] = [
            (0, "00000000"),
            (1, "00000001"),
            (0xF, "0000000f"),
            (0xFF, "000000ff"),
            (0x100, "00000100"),
            (0xFFFF, "0000ffff"),
            (0xF_FFFF, "000fffff"),
            (0xFF_FFFF, "00ffffff"),
            (0xFFF_FFFF, "0fffffff"),
            (0x1000_0000, "10000000"),
            (0xDEAD_BEEF, "deadbeef"),
            (0xFFFF_FFFF, "ffffffff"),  // max CRC-32 value
        ]

        for (checksum, expected) in expectations {
            #expect(current(checksum) == expected, "current(\(checksum))")
            #expect(legacy(checksum) == expected, "legacy(\(checksum))")
        }
    }

    @Test func zeroPadsShortValuesToEightLowercaseHexDigits() {
        for checksum: UInt in [0, 1, 0xAB, 0x1234, 0xFFFF_FFFF] {
            let hex = current(checksum)
            #expect(hex.count == 8, "width for \(checksum)")
            #expect(hex == hex.lowercased(), "lowercase for \(checksum)")
        }
    }

    // Exhaustive over the low range, which exercises 1...5 hex digits and every zero-pad width.
    @Test func matchesAcrossLowRange() {
        var firstMismatch: UInt?

        for checksum in UInt(0)...0x2_0000 where current(checksum) != legacy(checksum) {
            firstMismatch = checksum
            break
        }

        #expect(firstMismatch == nil, "first mismatch at \(firstMismatch ?? 0)")
    }

    // Strided sweep across the full 32-bit CRC-32 domain with an odd stride for varied bit
    // patterns, sampling ~100k values up to and including 0xFFFFFFFF.
    @Test func matchesAcrossStrided32BitSweep() {
        var firstMismatch: UInt?
        var checked = 0
        var checksum: UInt = 0

        while checksum <= 0xFFFF_FFFF {
            if current(checksum) != legacy(checksum) { firstMismatch = checksum; break }
            checked += 1
            checksum &+= 0x9E37
        }

        #expect(firstMismatch == nil, "first mismatch at \(firstMismatch ?? 0)")
        #expect(checked > 100_000, "expected a dense sweep, only checked \(checked)")
    }

    // Out of the CRC-32 domain, the two diverge: `%x` truncates to the low 32 bits while
    // `String(_:radix:)` keeps the full value. `crc32` never returns such values, so this
    // is unreachable in production — it documents the boundary (and the bug the swap fixed).
    @Test func divergesOnlyAboveThirtyTwoBits() {
        #expect(current(0x1_0000_0000) != legacy(0x1_0000_0000))
        #expect(legacy(0x1_0000_0000) == "00000000")   // truncated low 32 bits
        #expect(current(0x1_0000_0000) == "100000000")  // full value preserved
    }
}
