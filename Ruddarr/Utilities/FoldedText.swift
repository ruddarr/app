import Foundation

struct FoldedText: Sendable {
    private let bytes: [UInt8]

    init(_ text: String) {
        bytes = Array(text.lowercased().utf8)
    }

    func contains(_ other: FoldedText) -> Bool {
        let needle = other.bytes

        guard let first = needle.first else { return true }
        guard bytes.count >= needle.count else { return false }

        let last = bytes.count - needle.count
        var start = 0

        while start <= last {
            if bytes[start] == first && matches(needle, at: start) {
                return true
            }

            start += 1
        }

        return false
    }

    private func matches(_ needle: [UInt8], at start: Int) -> Bool {
        var offset = 1

        while offset < needle.count {
            if bytes[start + offset] != needle[offset] {
                return false
            }

            offset += 1
        }

        return true
    }
}
