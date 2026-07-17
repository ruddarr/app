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
    func decode<T>(_ type: LenientDecoded<T>.Type, forKey key: Key) throws -> LenientDecoded<T> {
        try decodeIfPresent(type, forKey: key) ?? LenientDecoded(wrappedValue: nil)
    }

    func decodeLossyArrayIfPresent<T: Decodable>(
        _ type: [T].Type,
        forKey key: Key
    ) throws -> [T]? {
        try decodeIfPresent([T?].self, forKey: key)?.compactMap { $0 }
    }
}

extension KeyedEncodingContainer {
    mutating func encode<T>(_ value: LenientDecoded<T>, forKey key: Key) throws {
        try encodeIfPresent(value.wrappedValue, forKey: key)
    }
}

@propertyWrapper
struct LenientDecoded<Wrapped: Codable & Equatable>: Codable, Equatable {
    var wrappedValue: Wrapped?

    init(wrappedValue: Wrapped?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = try? container.decode(Wrapped.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension LenientDecoded: Sendable where Wrapped: Sendable {}
