import SwiftUI

struct HistoryView: View {
    @State private var page: Int = 1
    @State private var history: History = .init()
    @State private var selectedEvent: MediaHistoryEvent?

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(events) { event in
                    MediaHistoryItem(event: event)
                        .onTapGesture { selectedEvent = event }
                }

                if !events.isEmpty {
                    Group {
                        if history.isLoading {
                            ProgressView().tint(.secondary)
                        } else if history.hasMore.values.contains(true) {
                            Button("Load More") {
                                page += 1
                                Task { await history.fetch(page) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }.padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .viewPadding(.horizontal)
            .sheet(item: $selectedEvent) { event in
                MediaEventSheet(event: event)
                    .presentationDetents(
                        event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                    )
            }
        }
        .onAppear {
            history.instances = settings.instances
        }
        .task {
            await history.fetch(page)
        }
        .navigationBarTitle("History", displayMode: .inline)
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
                ContentUnavailableView("No Tasks", systemImage: "slash.circle")
            }
        }
    }

    var events: [MediaHistoryEvent] {
        var items = history.events

        return items.sorted { $0.date > $1.date }
    }
}

#Preview {
    dependencies.router.selectedTab = .activity

    return ContentView()
        .withAppState()
}
