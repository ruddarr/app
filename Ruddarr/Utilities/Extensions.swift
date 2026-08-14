import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension Sequence where Element == UInt8 {
    func hexEncoded() -> String {
        map { String($0 >> 4, radix: 16) + String($0 & 0xF, radix: 16) }.joined()
    }
}

extension String {
    var htmlDecoded: String {
        let attr = try? NSAttributedString(data: Data(utf8), options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ], documentAttributes: nil)

        return (attr?.string ?? self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func singleLined() -> String {
        replacingOccurrences(of: "\\s*\n\\s*", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension MutableCollection where Element: Identifiable {
    mutating func revert(_ keyPath: WritableKeyPath<Element, Bool>, to original: Bool, id: Element.ID) {
        guard let index = firstIndex(where: { $0.id == id }) else { return }

        if self[index][keyPath: keyPath] == !original {
            self[index][keyPath: keyPath] = original
        }
    }
}
