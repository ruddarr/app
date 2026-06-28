import Foundation

extension String {
    /// Substitutes `String(format:)`-style placeholders using only safe string operations —
    /// a memory-safe replacement for `String(format:)` for localized templates and the like.
    ///
    /// Treats `%@`, `%d`, `%i` and `%lld` — sequential, or positional `%1$@` / `%2$d` / … — as
    /// substitution slots and `%%` as a literal `%`. Each slot consumes one argument, which
    /// may be any `LosslessStringConvertible` (`Int`, `String`, …) and is inserted via its
    /// `description`. Width/precision specifiers (`%.1f`, `%02d`, …) are left verbatim; format
    /// those with a `FormatStyle` first.
    func placeholders(_ arguments: any LosslessStringConvertible...) -> String {
        placeholders(arguments)
    }

    // Scans the UTF-8 view rather than `Character`s: the markers (`%`, `@`, `$`, digits) are
    // single-byte ASCII that can't collide with multi-byte sequences, so this avoids
    // grapheme-boundary work and copies literal runs in bulk — several times faster than a
    // `Character`-based scan, and allocation-free when there's no placeholder.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func placeholders(_ arguments: [any LosslessStringConvertible]) -> String {
        let utf8 = self.utf8

        guard let firstPercent = utf8.firstIndex(of: 0x25 /* % */) else { return self }

        var result = ""
        result.reserveCapacity(utf8.count)
        result.append(contentsOf: self[..<firstPercent])

        var nextArgument = 0
        var index = firstPercent
        let end = utf8.endIndex

        while index < end {
            // Copy a literal run (everything up to the next '%') in one bulk append.
            if utf8[index] != 0x25 {
                let runStart = index
                repeat {
                    index = utf8.index(after: index)
                } while index < end && utf8[index] != 0x25
                result.append(contentsOf: self[runStart..<index])
                continue
            }

            // index is at '%'.
            let mark = utf8.index(after: index)

            // Trailing '%'.
            if mark == end {
                result.append("%")
                break
            }

            let next = utf8[mark]

            // "%%" → literal '%'.
            if next == 0x25 {
                result.append("%")
                index = utf8.index(after: mark)
                continue
            }

            // Fast path: a plain sequential "%@" / "%d" / "%i" (the common case).
            if next == 0x40 || next == 0x64 || next == 0x69 { // '@', 'd', 'i'
                if nextArgument < arguments.count {
                    result.append(arguments[nextArgument].description)
                }
                nextArgument += 1
                index = utf8.index(after: mark)
                continue
            }

            // Slow path: an optional positional index ("2$"), an optional "ll" length modifier
            // (printf's long long, used by some String Catalog plural keys), then the conversion.
            // Covers "%lld", "%2$@", "%2$lld", …
            var conversion = mark
            var position = -1 // -1 = sequential

            // Optional positional index, e.g. the "2$" in "%2$@".
            if next >= 0x30, next <= 0x39 { // 0–9
                var value = 0
                var cursor = mark
                while cursor < end, utf8[cursor] >= 0x30, utf8[cursor] <= 0x39 {
                    value = value * 10 + Int(utf8[cursor] - 0x30)
                    cursor = utf8.index(after: cursor)
                }
                guard cursor < end, utf8[cursor] == 0x24 else { // '$'
                    result.append("%")
                    index = utf8.index(after: index)
                    continue
                }
                position = value
                conversion = utf8.index(after: cursor) // past '$'
            }

            // Optional "ll" length modifier.
            if conversion < end, utf8[conversion] == 0x6c { // 'l'
                let secondL = utf8.index(after: conversion)
                guard secondL < end, utf8[secondL] == 0x6c else { // 'l'
                    result.append("%")
                    index = utf8.index(after: index)
                    continue
                }
                conversion = utf8.index(after: secondL)
            }

            // The conversion must be '@', 'd' or 'i'; anything else is left verbatim.
            guard conversion < end,
                  utf8[conversion] == 0x40 || utf8[conversion] == 0x64 || utf8[conversion] == 0x69
            else {
                result.append("%")
                index = utf8.index(after: index)
                continue
            }

            let argument = position < 0 ? nextArgument : position - 1
            if argument >= 0, argument < arguments.count {
                result.append(arguments[argument].description)
            }
            if position < 0 {
                nextArgument += 1
            }
            index = utf8.index(after: conversion)
        }

        return result
    }
}
