import Foundation
import SwiftUI

extension UUID: RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }

    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}

extension Array<Instance>: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension MovieSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8)
            else { return nil }
            let result = try JSONDecoder().decode(MovieSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "movie.sort", message: "init failed", data: ["error": error])

            return nil
        }
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return result
    }
}

extension MovieSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case filter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            filter: container.decode(Filter.self, forKey: .filter)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(filter, forKey: .filter)
    }
}
