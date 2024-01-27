import SwiftUI

class AppSettings: ObservableObject {
    @CloudStorage("instances") var instances: [Instance] = []

    @AppStorage("radarrInstanceId", store: dependencies.store) var radarrInstanceId: Instance.ID?

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

    var radarrInstances: [Instance] {
        instances.filter { instance in
            instance.type == .radarr
        }
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
    }

    func deleteInstance(_ instance: Instance) {
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances.remove(at: index)
        }
    }
}
