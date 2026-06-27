import Foundation

extension Sequence where Element == UInt8 {
    /// Lowercase, zero-padded hexadecimal encoding of every byte.
    ///
    /// A memory-safe replacement for `map { String(format: "%02hhx", $0) }.joined()`:
    /// each byte becomes exactly two characters by encoding its high and low nibble
    /// separately. Works on `Data`, CryptoKit digests, and any other `UInt8` sequence.
    func hexEncoded() -> String {
        map { String($0 >> 4, radix: 16) + String($0 & 0xF, radix: 16) }.joined()
    }
}
