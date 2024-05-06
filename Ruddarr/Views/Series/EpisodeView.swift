import SwiftUI

struct EpisodeView: View {
    var series: Series
    var episodeId: Episode.ID

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    @Environment(\.dismiss) private var dismiss

    let smallScreen = UIDevice.current.userInterfaceIdiom == .phone

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)
                        .padding(.trailing, 25)

                    // TODO: fix me
//                    actions
//                        .padding(.bottom)
//
//                    details
//                        .padding(.bottom)
                }
                .padding(.top)
                .viewPadding(.horizontal)
            }
            // TODO: fix me
//            .alert(
//                isPresented: instance.movies.errorBinding,
//                error: instance.movies.error
//            ) { _ in
//                Button("OK") { instance.movies.error = nil }
//            } message: { error in
//                Text(error.recoverySuggestionFallback)
//            }
        }

        // file details (media etc.)
        // monitor button
        // search buttons
        // history
    }

    var episode: Episode {
        instance.episodes.items.first { $0.id == episodeId }!
    }

    var header: some View {
        VStack(alignment: .leading) {
            Text(episode.statusLabel)
            .font(.footnote)
            .fontWeight(.semibold)
            .tracking(1.1)
            .foregroundStyle(settings.theme.tint)

            Text(episode.titleLabel)
                .font(.title2)
                .fontWeight(.bold)
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(episode.episodeLabel)
                Bullet()
                Text(episode.airDateLabel)

                if let runtime = episode.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if episode.overview != nil {
                description
                    .padding(.top, 6)
            }
        }
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(episode.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 3 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.35)) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = smallScreen
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    let episodes: [Episode] = PreviewData.load(name: "series-episodes")

    return EpisodeView(series: item, episode: episodes[22])
        .withAppState()
}
