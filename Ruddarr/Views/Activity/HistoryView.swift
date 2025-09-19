import SwiftUI

struct HistoryView: View {
    @State private var page: Int = 1
    @State private var history = History()
    @State private var selectedEvent: MediaHistoryEvent?
    @State private var displayedInstance: String = ".all"
    @State private var displayedEventType: String = ".all"

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(events) { event in
                    MediaHistoryItem(event: event)
                        .environmentObject(settings)
                        .onTapGesture { selectedEvent = event }
                }

                if !events.isEmpty {
                    Group {
                        if history.isLoading {
                            ProgressView().tint(.secondary)
                        } else if history.hasMore.values.contains(true) {
                            Button("Load More") {
                                page += 1
                                Task { await history.fetch(page, displayedEventType) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .viewPadding(.horizontal)
            .sheet(item: $selectedEvent) { event in
                MediaEventSheet(event: event, instanceId: event.instanceId)
                    .environmentObject(settings)
                    .presentationDetents(
                        dynamic: event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                    )
            }
        }
        .navigationTitle("History")
        .safeNavigationBarTitleDisplayMode(.inline)
        .task {
            history.instances = settings.instances
            await history.fetch(page, displayedEventType)
        }
        .toolbar {
            filtersMenu
        }
        .refreshable {
            await Task { await history.fetch(1, displayedEventType) }.value
        }
        .onChange(of: displayedEventType) {
            Task { await history.fetch(1, displayedEventType) }
        }
        .alert(
            isPresented: history.errorBinding,
            error: history.error
        ) { _ in
            Button("OK") { history.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .overlay {
            if history.events.isEmpty && history.isLoading {
                Loading()
            } else if history.events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "slash.circle")
            } else if events.isEmpty {
                noMatchingEvents
            }
        }
    }

    var events: [MediaHistoryEvent] {
        var items = history.events

        if displayedInstance != ".all" {
            items = items.filter { $0.instanceId?.isEqual(to: displayedInstance) == true }
        }

        if displayedEventType != ".all" {
            items = items.filter { $0.eventType.ref == displayedEventType }
        }

        return items.sorted { $0.date > $1.date }
    }

    var filtersMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if history.instances.count > 1 {
                    instancePicker
                }

                Picker(selection: $displayedEventType, label: Text("Event Type")) {
                    Text("All Events", comment: "(Short) History event filter").tag(".all")
                    Text("Grabbed", comment: "(Short) History event filter").tag(".grabbed")
                    Text("Imported", comment: "(Short) History event filter").tag(".imported")
                    Text("Failed", comment: "(Short) History event filter").tag(".failed")
                    Text("Ignored", comment: "(Short) History event filter").tag(".ignored")
                    Text("Renamed", comment: "(Short) History event filter").tag(".renamed")
                    Text("Deleted", comment: "(Short) History event filter").tag(".deleted")
                }
                .pickerStyle(.inline)
            } label: {
                if displayedInstance != ".all" {
                    Image("filters.badge").offset(y: 3.2)
                } else {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
            .tint(.primary)
            .menuIndicator(.hidden)
        }
    }

    var instancePicker: some View {
        Menu {
            Picker("Instance", selection: $displayedInstance) {
                Text("Any Instance").tag(".all")

                ForEach(history.instances) { instance in
                    Text(instance.label).tag(instance.id.uuidString)
                }
            }
            .pickerStyle(.inline)
        } label: {
            let label = history.instances.first {
                $0.id.uuidString == displayedInstance
            }?.label ?? String(localized: "Instance")

            Label(label, systemImage: "internaldrive")
        }
    }

    var noMatchingEvents: some View {
        ContentUnavailableView {
            Label("No Events Match", systemImage: "slash.circle")
        } description: {
            Text("No events match the selected filters.")
        } actions: {
            Button("Clear Filters") {
                displayedInstance = ".all"
                displayedEventType = ".all"
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .withAppState()
    }
}
