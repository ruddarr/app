import Defaults
import SwiftUI
import Foundation

@Observable @MainActor
final class AppSettings {
    static let shared = AppSettings()

    // Real stored properties (not `@Default`, which is `DynamicProperty` and
    // only reactive inside a `View`). Values are seeded from and persisted to
    // `Defaults`, so SwiftUI tracks them and changes propagate across views.
    var instances: [Instance] { didSet { Defaults[.instances] = instances.rawValue } }

    var icon: AppIcon { didSet { Defaults[.icon] = icon } }
    var theme: Theme { didSet { Defaults[.theme] = theme } }
    var appearance: Appearance { didSet { Defaults[.appearance] = appearance } }
    var grid: GridStyle { didSet { Defaults[.grid] = grid } }
    var tab: TabItem { didSet { Defaults[.tab] = tab } }
    var releaseFilters: ReleaseFilters { didSet { Defaults[.releaseFilters] = releaseFilters } }

    var radarrInstanceId: Instance.ID? { didSet { Defaults[.radarrInstanceId] = radarrInstanceId } }
    var sonarrInstanceId: Instance.ID? { didSet { Defaults[.sonarrInstanceId] = sonarrInstanceId } }

    @ObservationIgnored private var instancesSync: Task<Void, Never>?

    private init() {
        instances = [Instance](rawValue: Defaults[.instances]) ?? []
        icon = Defaults[.icon]
        theme = Defaults[.theme]
        appearance = Defaults[.appearance]
        grid = Defaults[.grid]
        tab = Defaults[.tab]
        releaseFilters = Defaults[.releaseFilters]
        radarrInstanceId = Defaults[.radarrInstanceId]
        sonarrInstanceId = Defaults[.sonarrInstanceId]

        // Mirror external changes (iCloud sync from other devices) back into the
        // observable state so the UI updates live. Our own writes re-emit with an
        // unchanged value and are filtered out by the equality guard.
        instancesSync = Task { [weak self] in
            for await raw in Defaults.updates(.instances, initial: false) {
                let value = [Instance](rawValue: raw) ?? []
                guard let self, self.instances != value else { continue }
                self.instances = value
            }
        }
    }

    func resetAll() {
        dependencies.store.removePersistentDomain(forName: Ruddarr.group)

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        instances = []
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

enum ReleaseFilters: String, Identifiable, CaseIterable, Defaults.Serializable {
    var id: Self { self }

    case reset
    case preserve

    var label: String {
        switch self {
        case .reset: return String(localized: "Reset", comment: "(Preferences) Reset release filters")
        case .preserve: return String(localized: "Preserve", comment: "(Preferences) Preserve release filters")
        }
    }
}
