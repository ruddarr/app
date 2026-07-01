import Foundation

#if DEBUG
struct InstanceSeed: Decodable {
    var id: UUID?
    var type: InstanceType
    var label: String?
    var url: String
    var apiKey: String
    var mode: String?
    var headers: [Header]?

    struct Header: Decodable {
        var name: String
        var value: String
    }

    enum CodingKeys: String, CodingKey {
        case id, type, label, url, apiKey, mode, headers
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        id = try values.decodeIfPresent(UUID.self, forKey: .id)
        let rawType = try values.decode(String.self, forKey: .type)
        type = rawType.caseInsensitiveCompare("sonarr") == .orderedSame ? .sonarr : .radarr
        label = try values.decodeIfPresent(String.self, forKey: .label)
        url = try values.decode(String.self, forKey: .url)
        apiKey = try values.decode(String.self, forKey: .apiKey)
        mode = try values.decodeIfPresent(String.self, forKey: .mode)
        headers = try values.decodeIfPresent([Header].self, forKey: .headers)
    }

    static func load() -> [InstanceSeed] {
        guard
            let path = Bundle.main.path(forResource: "seed-instances", ofType: "json"),
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        else {
            return []
        }

        return (try? JSONDecoder().decode([InstanceSeed].self, from: data)) ?? []
    }

    func merged(into existing: Instance?) -> Instance {
        var instance = existing ?? Instance(id: id ?? UUID())

        instance.type = type
        instance.url = url
        instance.apiKey = apiKey

        if let label, !label.isEmpty {
            instance.label = label
        }

        if let mode {
            instance.mode = mode.caseInsensitiveCompare("slow") == .orderedSame ? .slow : .normal
        }

        if let headers {
            instance.headers = headers.map { InstanceHeader(name: $0.name, value: $0.value) }
        }

        return instance
    }
}

extension AppSettings {
    @discardableResult
    func seedInstances() -> Int {
        let seeds = InstanceSeed.load()

        for seed in seeds {
            saveInstance(seed.merged(into: existingInstance(for: seed)))
        }

        return seeds.count
    }

    private func existingInstance(for seed: InstanceSeed) -> Instance? {
        if let id = seed.id, let match = instanceById(id) {
            return match
        }

        return instances.first {
            $0.type == seed.type && $0.url.caseInsensitiveCompare(seed.url) == .orderedSame
        }
    }
}
#endif
