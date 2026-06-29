import SwiftUI
import Foundation
import CloudStorage
import Combine

// We can't migrate this to `@Observable` because `@AppStorage` isn't supported
// We could use https://github.com/sindresorhus/Defaults instead maybe
@MainActor
class AppSettings: ObservableObject {
    // Source of truth for instances. In production this stays in iCloud
    // (`@CloudStorage`) so instances keep syncing across a user's devices. Reads
    // and writes go through the `instances` computed property below, which also
    // keeps an App Group mirror in sync for extensions to read.
    #if DEBUG
        @AppStorage("debugInstances", store: dependencies.store) private var storedInstances: [Instance] = []
    #else
        @CloudStorage("instances") private var storedInstances: [Instance] = []
    #endif

    var instances: [Instance] {
        get { storedInstances }
        set {
            storedInstances = newValue
            AppSettings.mirrorInstances(newValue)
        }
    }

    @AppStorage("icon", store: dependencies.store) var icon: AppIcon = .factory
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory
    @AppStorage("appearance", store: dependencies.store) var appearance: Appearance = .automatic
    @AppStorage("grid", store: dependencies.store) var grid: GridStyle = .posters

    @AppStorage("tab", store: dependencies.store) var tab: TabItem = .movies
    @AppStorage("releaseFilters", store: dependencies.store) var releaseFilters: ReleaseFilters = .reset

    @AppStorage("radarrInstanceId", store: dependencies.store) var radarrInstanceId: Instance.ID?
    @AppStorage("sonarrInstanceId", store: dependencies.store) var sonarrInstanceId: Instance.ID?

    func resetAll() {
        instances.removeAll()

        // Wipe the App Group suite (where `dependencies.store` now lives)...
        dependencies.store.removePersistentDomain(forName: UserDefaults.appGroup)

        // ...and the legacy standard domain that the App Group migration copied from,
        // so a reset leaves nothing behind to be re-migrated on next launch.
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
    }
}

extension AppSettings {
    /// Key used for the App Group mirror of `instances`, read by app extensions.
    static let instancesMirrorKey = "instances"

    /// Mirrors `instances` into the shared App Group suite so extensions can read
    /// them. The mirror is a read-only copy — the source of truth remains
    /// `@CloudStorage`/`@AppStorage`. Reuses the same JSON serialization as the
    /// property wrappers (`Array<Instance>.rawValue`), so the format matches and
    /// extensions can decode with `[Instance](rawValue:)`.
    static func mirrorInstances(_ instances: [Instance]) {
        let value = instances.rawValue

        // Only write when changed to avoid needless churn (e.g. on every launch).
        guard dependencies.store.string(forKey: instancesMirrorKey) != value else { return }

        dependencies.store.set(value, forKey: instancesMirrorKey)
    }

    /// Re-reads the authoritative instances and refreshes the App Group mirror.
    /// Call on launch and whenever iCloud reports an external change.
    @MainActor
    static func refreshInstancesMirror() {
        mirrorInstances(AppSettings().instances)
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

enum ReleaseFilters: String, Identifiable, CaseIterable {
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
