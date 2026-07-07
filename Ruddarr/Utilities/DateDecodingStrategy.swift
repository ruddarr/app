import Foundation

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601extended = custom { decoder in
        let string = try decoder.singleValueContainer().decode(String.self)

        // `Date.ISO8601FormatStyle` is `Sendable`, so it needs no shared formatter.
        if let date = try? Date(string, strategy: .iso8601) {
            return date
        }

        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) {
            return date
        }

        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Expected date string to be ISO8601-formatted."
        ))
    }
}

extension KeyedDecodingContainer {
    func decodeLossyArrayIfPresent<T: Decodable>(
        _ type: [T].Type,
        forKey key: Key
    ) throws -> [T]? {
        try decodeIfPresent([T?].self, forKey: key)?.compactMap { $0 }
    }
}
