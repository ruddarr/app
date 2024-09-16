import SwiftUI
import Foundation
import CloudStorage

// We can't migrate this to `@Observable` because `@AppStorage` isn't supported
// We could use https://github.com/sindresorhus/Defaults instead maybe
class AppSettings: ObservableObject {
    @CloudStorage("instances") var instances: [Instance] = []

    @AppStorage("icon", store: dependencies.store) var icon: AppIcon = .factory
    @AppStorage("theme", store: dependencies.store) var theme: Theme = .factory
    @AppStorage("appearance", store: dependencies.store) var appearance: Appearance = .automatic
    @AppStorage("tab", store: dependencies.store) var tab: Tab = .movies
    @AppStorage("radarrInstanceId", store: dependencies.store) var radarrInstanceId: Instance.ID?
    @AppStorage("sonarrInstanceId", store: dependencies.store) var sonarrInstanceId: Instance.ID?

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

    func instanceById(_ id: UUID) -> Instance? {
        instances.first(where: { $0.id == id })
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

        deleteInstanceWebhook(deletedInstance)
        deleteInstanceIndex(deletedInstance)

        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances.remove(at: index)
        }

        Queue.shared.instances = instances
    }

    private func deleteInstanceWebhook(_ instance: Instance) {
        let webhook = InstanceWebhook(instance)

        Task.detached { [webhook] in
            await webhook.delete()
        }
    }

    private func deleteInstanceIndex(_ instance: Instance) {
        Task.detached { [instance] in
            await Spotlight.of(instance).deleteInstanceIndex()
        }
    }
}
