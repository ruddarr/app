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

            if smallScreen {
                actions
                    .padding(.bottom)
            }
            // TODO: needs work
//            if movie.exists {
//                information
//                    .padding(.bottom)
//            }
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
            if series.exists {
                movieActions
            } else {
                previewActions
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var movieActions: some View {
        Group {
            Button {
                Task { @MainActor in
                    // TODO: which command should fire?
                    guard await instance.series.command(series, command: .automaticSearch) else {
                        return
                    }

                    dependencies.toast.show(.searchQueued)

                    TelemetryManager.send("automaticSearchDispatched")
                }
            } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.series.isWorking)

            NavigationLink(value: SeriesView.Path.releases(series.id), label: {
                ButtonLabel(text: "Interactive", icon: "person.fill")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
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
    let item = series.first(where: { $0.id == 235 }) ?? series[0]

    return SeriesDetailView(series: Binding(get: { item }, set: { _ in }))
        .withSettings()
        .withSonarrInstance(series: series)
}

#Preview("Preview") {
    let series: [Series] = PreviewData.load(name: "series-lookup")
    let item = series.first(where: { $0.id == 235 }) ?? series[0]

    return SeriesDetailView(series: Binding(get: { item }, set: { _ in }))
        .withSettings()
        .withSonarrInstance(series: series)
}
