public import Foundation
import Defaults

extension UUID: @retroactive RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }

    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}

extension Array<Instance>: @retroactive RawRepresentable {
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

extension UUID: Defaults.Serializable {
    public static let bridge = Defaults.RawRepresentableBridge<UUID>()
}

extension Array<Instance>: Defaults.Serializable {
    public static let bridge = Defaults.RawRepresentableBridge<[Instance]>()
}
