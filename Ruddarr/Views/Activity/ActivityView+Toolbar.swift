import SwiftUI

extension ActivityView {
    var protocols: [String] {
        var seen = Set<String>()

        return queue.items.values
            .flatMap { $0 }
            .map { $0.type.label }
            .filter { seen.insert($0).inserted }
    }

    var clients: [String] {
        var seen = Set<String>()

        return queue.items.values
            .flatMap { $0 }
            .compactMap { $0.downloadClient }
            .filter { seen.insert($0).inserted }
    }

    func updateSortDirection() {
        switch sort.option {
        case .byAdded:
            sort.isAscending = false
        default:
            sort.isAscending = true
        }
    }

    @ToolbarContentBuilder
    var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack {
                toolbarFilterButton
                toolbarSortingButton
            }
            .tint(.primary)
        }

        if !settings.configuredInstances.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    HistoryView().environmentObject(settings)
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .imageScale(.medium)
                }.tint(.primary)
            }
        }
    }

    var toolbarFilterButton: some View {
        Menu {
            if queue.instances.count > 1 {
                instancePicker
            }

            if protocols.count > 1 {
                protocolPicker
            }

            if clients.count > 1 {
                clientPicker
            }

            Section {
                Toggle("Issues", systemImage: "exclamationmark.triangle", isOn: $sort.issues)
            }
        } label: {
            if sort.hasFilter {
                Image("filters.badge").offset(y: 3.2)
            } else{
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
    }

    var instancePicker: some View {
        Menu {
            Picker("Instance", selection: $sort.instance) {
                Text("Any Instance").tag(".all")

                ForEach(queue.instances) { instance in
                    Text(instance.label).tag(instance.id.uuidString)
                }
            }
            .pickerStyle(.inline)
        } label: {
            let label = queue.instances.first {
                $0.id.uuidString == sort.instance
            }?.label ?? String(localized: "Instance")

            Label(label, systemImage: "internaldrive")
        }
    }

    var protocolPicker: some View {
        Menu {
            Picker("Protocol", selection: $sort.client) {
                Text("Any Protocol").tag(".all")

                ForEach(protocols, id: \.self) { type in
                    Text(type)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.type == ".all" ? "Protocol" : sort.type,
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
    }

    var clientPicker: some View {
        Menu {
            Picker("Client", selection: $sort.client) {
                Text("Any Client").tag(".all")

                ForEach(clients, id: \.self) { client in
                    Text(client)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.type == ".all" ? "Client" : sort.type,
                systemImage: "apple.terminal"
            )
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Section {
                Picker("Sort By", selection: $sort.option) {
                    ForEach(QueueSort.Option.allCases) { option in
                        option.label
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Picker("Direction", selection: $sort.isAscending) {
                    Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                    Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                }.pickerStyle(.inline)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }
}
