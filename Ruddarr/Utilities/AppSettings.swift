import SwiftUI

class AppSettings: ObservableObject {
    @CloudStorage("instances") var instances: [Instance] = []

    func resetAll() {
        instances.removeAll()
    }
}

extension AppSettings {
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

    func fetchInstanceMetadata(_ instanceId: UUID) async throws {
        guard var instance = instanceById(instanceId) else {
            throw AppError("Instance not found: \(instanceId)")
        }

        instance.rootFolders = try await dependencies.api.rootFolders(instance)
        instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)

        saveInstance(instance)
    }
}

extension View {
    func withSettings() -> some View {
        self.environmentObject(AppSettings())
    }
}
