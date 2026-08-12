import Testing
import Foundation

// Validates `Sequence<UInt8>.hexEncoded()` in Ruddarr/Utilities/HexEncoding.swift,
// the shared helper that replaced `String(format: "%02hhx", $0)` to resolve unsafe
// `String(format:)` warnings. It is used at every former call site (Images.sha1,
// NotificationService poster hashing, and the APNs device-token formatting in
// AppDelegate/AppDelegateMac). These tests exercise the real helper and prove it
// is byte-for-byte identical to the format-string original it replaced.
struct HexEncodingTests {
    /// The pre-change implementation, kept here as a reference oracle.
    private func legacy(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02hhx", $0) }.joined()
    }

    /// The production helper under test.
    private func current(_ bytes: [UInt8]) -> String {
        bytes.hexEncoded()
    }

    @Test func matchesLegacyForEveryByteValue() {
        for value in UInt8.min...UInt8.max {
            #expect(current([value]) == legacy([value]), "mismatch at byte \(value)")
        }
    }

    @Test func producesLowercaseZeroPaddedHex() {
        #expect(current([0x00]) == "00")
        #expect(current([0x0f]) == "0f")  // low nibble needs a letter
        #expect(current([0xf0]) == "f0")  // high nibble needs a letter
        #expect(current([0xa5]) == "a5")
        #expect(current([0xff]) == "ff")
        #expect(current([0x09]) == "09")  // padding: single digit stays two chars
    }

    @Test func eachByteEncodesToExactlyTwoChars() {
        for value in UInt8.min...UInt8.max {
            #expect(current([value]).count == 2, "byte \(value) was not two chars")
        }
    }

    @Test func encodesMultiByteSequencesInOrder() {
        let bytes: [UInt8] = [0xde, 0xad, 0xbe, 0xef]
        #expect(current(bytes) == "deadbeef")
        #expect(current(bytes) == legacy(bytes))
    }

    @Test func matchesLegacyOverDigestSizedData() {
        // Mirrors the real call sites, where fixed-width hash digests get hex-encoded:
        // a 16-byte (MD5) and a 20-byte (SHA-1) span of varied byte values.
        let md5Sized = (0..<16).map { UInt8(truncatingIfNeeded: $0 &* 17) }
        let sha1Sized = (0..<20).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }
        #expect(current(md5Sized) == legacy(md5Sized))
        #expect(current(sha1Sized) == legacy(sha1Sized))
    }

    @Test func encodesEmptyInputToEmptyString() {
        #expect(current([]).isEmpty)
    }
}
