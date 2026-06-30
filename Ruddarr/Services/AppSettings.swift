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
        InstancesStore.shared.reset()

        icon = .factory
        theme = .factory
        appearance = .automatic
        grid = .posters
        tab = .movies
        releaseFilters = .reset
        radarrInstanceId = nil
        sonarrInstanceId = nil

        dependencies.store.removePersistentDomain(forName: Ruddarr.group)

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
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
