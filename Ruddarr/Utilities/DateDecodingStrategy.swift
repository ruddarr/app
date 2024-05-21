import Foundation

extension DateFormatter {
    static var iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static var iso8601withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension JSONDecoder.DateDecodingStrategy {
    static var iso8601extended = custom { decoder in
        let string = try decoder.singleValueContainer().decode(String.self)

        if let date = DateFormatter.iso8601.date(from: string) {
            return date
        }

        if let date = DateFormatter.iso8601withFractionalSeconds.date(from: string) {
            return date
        }

        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Expected date string to be ISO8601-formatted."
        ))
    }
}
