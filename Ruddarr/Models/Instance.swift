import Foundation

struct Instance: Identifiable, Equatable, Codable {
    var id = UUID()
    var type: InstanceType = .radarr
    var label: String = ""
    var url: String = ""
    var apiKey: String = ""
}

enum InstanceType: String, Identifiable, CaseIterable, Codable {
    case radarr = "Radarr"
    case sonarr = "Sonarr"
    var id: Self { self }
}

extension Array<Instance>: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Instance].self, from: data)
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

extension UUID: RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }

    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}
