import SwiftUI

struct ShareInstance: Identifiable, Codable {
    let id: UUID
    let type: String
    let label: String
}

struct ShareInstanceStore {
    static let appGroupId = "group.com.ruddarr"

    static var instances: [ShareInstance] {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "instances") else {
            return []
        }

        return (try? JSONDecoder().decode([ShareInstance].self, from: data)) ?? []
    }

    static var radarrInstances: [ShareInstance] {
        instances.filter { $0.type == "radarr" }
    }

    static var sonarrInstances: [ShareInstance] {
        instances.filter { $0.type == "sonarr" }
    }
}

struct InstancePickerView: View {
    var instances: [ShareInstance]
    var onSelect: (ShareInstance) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List(instances) { instance in
                Button {
                    onSelect(instance)
                } label: {
                    Label(instance.label, systemImage: "internaldrive")
                }
            }
            .navigationTitle("Select Instance")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}
