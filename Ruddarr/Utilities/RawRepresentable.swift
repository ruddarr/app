public import Foundation

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
        guard let data = rawValue.data(using: .utf8) else { return nil }

        if let result = try? JSONDecoder().decode([Element].self, from: data) {
            self = result
            return
        }

        guard let salvaged = try? JSONDecoder().decode([FailableInstance].self, from: data) else {
            return nil
        }

        let recovered = salvaged.compactMap(\.value)
        guard !recovered.isEmpty else { return nil }

        self = recovered
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

private struct FailableInstance: Decodable {
    let value: Instance?

    init(from decoder: any Decoder) throws {
        value = try? Instance(from: decoder)
    }
}
