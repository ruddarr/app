import SwiftUI

struct EpisodeHistory: View {
    var episode: Episode

    @State private var eventSheet: MediaHistoryEvent?
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        Section {
            ForEach(instance.episodes.history.filter { $0.episodeId == episode.id }) { event in
                MediaHistoryItem(event: event)
                    .padding(.bottom, 4)
                    .onTapGesture { eventSheet = event }
            }
        } header: {
            Text("History").font(.title2.bold()).padding(.bottom, 6)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .presentationDetents(
                    dynamic: event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
                .presentationBackground(.sheetBackground)
        }
    }
}
