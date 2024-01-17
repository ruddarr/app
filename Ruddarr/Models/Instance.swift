import Foundation

struct Instance: Identifiable, Equatable, Codable {
    var id = UUID() // TODO: not a fan of generating random ids implicitly like this. It has already cost me some time (arguably just because I didn't realize we're doing this, but still). Why do we need this again? Isn't an instance uniquely identified by its url, or maybe its url + type + maybe some other metadata?
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

extension Instance {
    static var sample: Self {
        .init(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            url: "http://10.0.1.5:8310",
            apiKey: "8f45bce99e254f888b7a2ba122468dbe"
        )
    }
}
