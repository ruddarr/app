import SwiftUI

struct ShareInstanceStore {
    static let appGroupId = "group.com.ruddarr"

    static var instances: [Instance] {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "instances") else {
            return []
        }

        return (try? JSONDecoder().decode([Instance].self, from: data)) ?? []
    }

    static var radarrInstances: [Instance] {
        instances.filter { $0.type == .radarr }
    }

    static var sonarrInstances: [Instance] {
        instances.filter { $0.type == .sonarr }
    }
}

struct InstancePickerView: View {
    var instances: [Instance]
    var onSelect: (Instance) -> Void
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
