import SwiftUI
import Foundation

enum Theme: String, Identifiable, CaseIterable {
    case blue
    case red
    case purple
    case yellow
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .blue:
                .blue
        case .red:
                .red
        case .purple:
                .purple
        case .yellow:
                .yellow
        }
    }
}

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
