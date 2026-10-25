import SwiftUI

struct EpisodeHistory: View {
    var episode: Episode

    @State private var eventSheet: MediaHistoryEvent?
    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        Section {
            ForEach(instance.episodes.history.filter { $0.episodeId == episode.id }) { event in
                MediaHistoryItem(event: event)
                    .environment(settings)
                    .padding(.bottom, 4)
                    .onTapGesture { eventSheet = event }
            }
        } header: {
            Text("History").font(.title2.bold()).padding(.bottom, 6)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .environment(settings)
                .presentationDetents(
                    dynamic: event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
                .presentationBackground(.sheetBackground)
        }
    }
}
