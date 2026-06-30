import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var instances: [Instance] {
        get { InstancesStore.shared.instances }
        set { InstancesStore.shared.setInstances(newValue) }
    }

    var icon: AppIcon = AppSettings.load("icon", .factory) {
        didSet { AppSettings.persist(icon, "icon") }
    }

    var theme: Theme = AppSettings.load("theme", .factory) {
        didSet { AppSettings.persist(theme, "theme") }
    }

    var appearance: Appearance = AppSettings.load("appearance", .automatic) {
        didSet { AppSettings.persist(appearance, "appearance") }
    }

    var grid: GridStyle = AppSettings.load("grid", .posters) {
        didSet { AppSettings.persist(grid, "grid") }
    }

    var tab: TabItem = AppSettings.load("tab", .movies) {
        didSet { AppSettings.persist(tab, "tab") }
    }

    var releaseFilters: ReleaseFilters = AppSettings.load("releaseFilters", .reset) {
        didSet { AppSettings.persist(releaseFilters, "releaseFilters") }
    }

    var radarrInstanceId: Instance.ID? = AppSettings.loadOptional("radarrInstanceId") {
        didSet { AppSettings.persist(radarrInstanceId, "radarrInstanceId") }
    }

    var sonarrInstanceId: Instance.ID? = AppSettings.loadOptional("sonarrInstanceId") {
        didSet { AppSettings.persist(sonarrInstanceId, "sonarrInstanceId") }
    }

    func resetAll() {
        dependencies.store.removePersistentDomain(forName: Ruddarr.group)

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        dependencies.store.set(true, forKey: Migrations.appGroupKey)

        InstancesStore.shared.reset()

        icon = .factory
        theme = .factory
        appearance = .automatic
        grid = .posters
        tab = .movies
        releaseFilters = .reset
        radarrInstanceId = nil
        sonarrInstanceId = nil
    }
}

extension AppSettings {
    var radarrInstance: Instance? {
        radarrInstances.first(where: { $0.id == radarrInstanceId })
    }

    var sonarrInstance: Instance? {
        sonarrInstances.first(where: { $0.id == sonarrInstanceId })
    }

    var radarrInstances: [Instance] {
        instances.filter { $0.type == .radarr }
    }

    var sonarrInstances: [Instance] {
        instances.filter { $0.type == .sonarr }
    }

    var configuredInstances: [Instance] {
        instances.filter { !$0.id.uuidString.starts(with: "00000000") }
    }

    func instanceBy(_ idOrName: String?) -> Instance? {
        guard let idOrName else {
            return nil
        }

        if let id = UUID(uuidString: idOrName) {
            return instanceById(id)
        }

        return instances.first { $0.name == idOrName }
    }

    func instanceById(_ id: UUID) -> Instance? {
        instances.first { $0.id == id }
    }

    func saveInstance(_ instance: Instance) {
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index] = instance
        } else {
            instances.append(instance)
        }

        Queue.shared.instances = instances
    }

    func deleteInstance(_ instance: Instance) {
        var deletedInstance = instance
        deletedInstance.id = UUID()

        let webhook = InstanceWebhook(instance)

        Task {
            await webhook.delete()
            await Spotlight(instance.id).deleteInstanceIndex()
        }

        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances.remove(at: index)
        }

        Queue.shared.instances = instances
    }
}

private extension AppSettings {
    static func load<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
        dependencies.store.string(forKey: key).flatMap { T(rawValue: $0) } ?? fallback
    }

    static func loadOptional<T: RawRepresentable>(_ key: String) -> T? where T.RawValue == String {
        dependencies.store.string(forKey: key).flatMap { T(rawValue: $0) }
    }

    static func persist<T: RawRepresentable>(_ value: T, _ key: String) where T.RawValue == String {
        dependencies.store.set(value.rawValue, forKey: key)
    }

    static func persist<T: RawRepresentable>(_ value: T?, _ key: String) where T.RawValue == String {
        dependencies.store.set(value?.rawValue, forKey: key)
    }
}

extension AppSettings {
    func context() -> [String: Any] {
        var context: [String: Any] = [
            "icon": icon.rawValue,
            "theme": theme.rawValue,
            "tab": tab.rawValue,
            "appearance": appearance.rawValue,
        ]

        for instance in configuredInstances {
            let id = instance.id.shortened
            let type = instance.type.rawValue.lowercased()

            context["\(type)-\(id)"] = [
                "mode": instance.mode.value,
                "version": instance.version as Any,
                "webhook": Occurrence.date(of: "webhookUpdated:\(instance.id)")?
                    .formatted(.relative(presentation: .numeric)) as Any,
            ]
        }

        return context
    }
}

enum ReleaseFilters: String, Identifiable, CaseIterable {
    var id: Self { self }

    case reset
    case preserve

    var label: String {
        switch self {
        case .reset: String(localized: "Reset", comment: "(Preferences) Reset release filters")
        case .preserve: String(localized: "Preserve", comment: "(Preferences) Preserve release filters")
        }
    }
}

#if DEBUG
// MARK: - Instance seeding (debug builds only)
//
// Reads `seed-instances.json` from the app's Documents directory and upserts the
// instances it describes. Real credentials live in that file, which is never
// committed — see `seed-instances.example.json` and `scripts/seed-instances.sh`.
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

    static var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("seed-instances.json")
    }

    static func load() -> [InstanceSeed] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }

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
    /// Upserts every instance described in `seed-instances.json`. Existing instances
    /// (matched by `id`, otherwise by type + URL) are updated in place; missing ones
    /// are added. Returns the number of instances seeded.
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
