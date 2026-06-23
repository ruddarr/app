import Defaults
import SwiftUI
import Foundation

@Observable @MainActor
final class AppSettings {
    @ObservationIgnored @Default(.instances) var instances
    @ObservationIgnored @Default(.icon) var icon
    @ObservationIgnored @Default(.theme) var theme
    @ObservationIgnored @Default(.appearance) var appearance
    @ObservationIgnored @Default(.grid) var grid
    @ObservationIgnored @Default(.tab) var tab
    @ObservationIgnored @Default(.releaseFilters) var releaseFilters
    @ObservationIgnored @Default(.radarrInstanceId) var radarrInstanceId
    @ObservationIgnored @Default(.sonarrInstanceId) var sonarrInstanceId

    func resetAll() {
        instances.removeAll()

        if let bundleId = Bundle.main.bundleIdentifier {
            dependencies.store.removePersistentDomain(forName: bundleId)
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
