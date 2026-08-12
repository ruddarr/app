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

extension DecodingError {
    var context: DecodingError.Context {
        switch self {
        case .dataCorrupted(let context): context
        case .keyNotFound(_, let context): context
        case .typeMismatch(_, let context): context
        case .valueNotFound(_, let context): context
        @unknown default:
            DecodingError.Context(codingPath: [], debugDescription: "Unhandled decoding error occurred")
        }
    }

    var isUnexpectedResponseShape: Bool {
        switch self {
        case .typeMismatch, .dataCorrupted, .valueNotFound: context.codingPath.isEmpty
        default: false
        }
    }

    var codingPathDescription: String {
        context.codingPath.map(\.stringValue).joined(separator: ".")
    }

    var codingPathSignature: String {
        var components = context.codingPath.filter { $0.intValue == nil }.map(\.stringValue)

        if case .keyNotFound(let key, _) = self {
            components.append(key.stringValue)
        }

        return components.joined(separator: ".")
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ type: LossyDecoded<T>.Type, forKey key: Key) throws -> LossyDecoded<T> {
        try decodeIfPresent(type, forKey: key) ?? LossyDecoded(wrappedValue: nil)
    }

    func decodeLossyArrayIfPresent<T: Decodable>(
        _ type: [T].Type,
        forKey key: Key
    ) throws -> [T]? {
        try decodeIfPresent([T?].self, forKey: key)?.compactMap { $0 }
    }
}

@propertyWrapper
struct LossyDecoded<Wrapped: Codable & Equatable>: Codable, Equatable {
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

extension LossyDecoded: Sendable where Wrapped: Sendable {}
