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

extension String {
    func singleLined() -> String {
        replacingOccurrences(of: "\\s*\n\\s*", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension MutableCollection where Element: Identifiable {
    /// Reverts `keyPath` to `original` on the element matching `id`, but only if it still
    /// holds the flipped value — so undoing an optimistic toggle after a failed request
    /// doesn't clobber a value a concurrent refresh may have written.
    mutating func revert(_ keyPath: WritableKeyPath<Element, Bool>, to original: Bool, id: Element.ID) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }

        if self[index][keyPath: keyPath] == !original {
            self[index][keyPath: keyPath] = original
        }
    }
}
