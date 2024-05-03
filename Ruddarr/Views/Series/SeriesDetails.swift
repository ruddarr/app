import SwiftUI
import TelemetryClient

struct SeriesDetails: View {
    var series: Series

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    let smallScreen = UIDevice.current.userInterfaceIdiom == .phone

    var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.bottom)

            details
                .padding(.bottom)

            if hasDescription {
                description
                    .padding(.bottom)
            }

            if smallScreen && !series.exists {
                actions
                    .padding(.bottom)
            }

            if series.exists {
                // TODO: next episode (nzb360)
                seasons
                    .padding(.bottom)

                information
                    .padding(.bottom)
            }
        }
    }

    var hasDescription: Bool {
        !(series.overview ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(series.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
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

    var details: some View {
        Grid(alignment: .leading) {
            detailsRow("Status", value: "\(series.status.label)")

            if let network = series.network, !network.isEmpty {
                detailsRow("Network", value: network)
            }

            if !series.genres.isEmpty {
                detailsRow("Genre", value: series.genreLabel)
            }

// TODO: needs work
//            if movie.isDownloaded {
//                detailsRow("Video", value: videoQuality)
//                detailsRow("Audio", value: audioQuality)
//
//                if let languages = subtitles {
//                    detailsRow("Subtitles", value: languages)
//                }
//            }
        }
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            previewActions
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var previewActions: some View {
        Group {
            Menu {
                SeriesContextMenu(series: series)
            } label: {
                ButtonLabel(text: "Open In...", icon: "arrow.up.right.square")
                    .modifier(MoviePreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            // TODO: handle...
//            if let trailerUrl = MovieContextMenu.youTubeTrailer(movie.youTubeTrailerId) {
//                Button {
//                    UIApplication.shared.open(URL(string: trailerUrl)!)
//                } label: {
//                    let label: LocalizedStringKey = smallScreen ? "Trailer" : "Watch Trailer"
//
//                    ButtonLabel(text: label, icon: "play.fill")
//                        .modifier(MoviePreviewActionModifier())
//                }
//                .buttonStyle(.bordered)
//                .tint(.secondary)
            //} else {
                Spacer()
                    .modifier(MoviePreviewActionSpacerModifier())
            //}
        }
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == series.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    // TODO: Size on Disk for Movie, Series and Season?

    var seasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(series.seasons.reversed()) { season in
                NavigationLink(value: SeriesView.Path.season(series.id, season.id), label: {
                    VStack {
                        HStack(spacing: 12) {
                            Text(season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)")

                            if let statistics = season.statistics {
                                Text(statistics.label)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "bookmark")
                                .symbolVariant(season.monitored ? .fill : .none)
                        }
                        .padding(.vertical, 15)
                        .padding(.horizontal)
                    }
                    .background(.secondarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                })
                .tint(.primary)
            }
        }
    }

    func detailsRow(_ label: LocalizedStringKey, value: String) -> some View {
        GridRow(alignment: .top) {
            Text(label)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .padding(.trailing)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 2 }) ?? series[0]

    return SeriesDetailView(series: Binding(get: { item }, set: { _ in }))
        .withSonarrInstance(series: series)
        .withAppState()
}

#Preview("Preview") {
    let series: [Series] = PreviewData.load(name: "series-lookup")
    let item = series[1]

    return SeriesDetailView(series: Binding(get: { item }, set: { _ in }))
        .withSonarrInstance(series: series)
        .withAppState()
}
