import SwiftUI

struct HistoryView: View {
    @State private var history: History = .init()
    @State private var eventSheet: MediaHistoryEvent?
    @State private var page: Int = 0

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            Group {
                if history.items.isEmpty {
                    if history.isLoading {
                        ProgressView().tint(.secondary)
                    } else {
                        ContentUnavailableView(
                            "No Tasks",
                            systemImage: "slash.circle"
                        )
                    }
                } else if history.error != nil {
                    ContentUnavailableView(
                        "An error occurred.",
                        systemImage: "exclamationmark.warninglight"
                    )
                } else {
                    ForEach(history.items) { event in
                        MediaHistoryItem(event: event)
                            .padding(.bottom, 4)
                            .onTapGesture { eventSheet = event }
                    }

                    if history.isLoading {
                        ProgressView()
                    } else if history.hasMore.values.contains(true) {
                        Button("Load More") {
                            page += 1
                            Task { await history.fetch(page) }
                        }
                    }
                }
            }
            .padding(.vertical)
            .viewPadding(.horizontal)
        }
        .navigationBarTitle("History", displayMode: .inline)
        .onAppear {
            history.instances = settings.instances
            page = 1
        }
        .task {
            await history.fetch(page)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .presentationDetents(
                    event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
        }
    }
}
