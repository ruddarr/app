import Foundation
import SwiftUI
// we need this boilerplate to store Codable stuff in AppStorage. Swift currently makes it hard to make this fully generic.
extension UUID: RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }

    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}

// I think we can only conform Array once, if we need more, we'll need to start wrapping it in another type.
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
            print(error)
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
        case option
        case isAscending
    }
    
    // !!! this is needed. If we don't implement decode/encode ourselves, the default implementations will try to optimize by using the RawRepresentable conformance instead and end up in a loop
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option)
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(option, forKey: .option)
        try container.encode(isAscending, forKey: .isAscending)
    }
}
