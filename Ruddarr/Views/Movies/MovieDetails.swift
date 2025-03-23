import SwiftUI
import TelemetryDeck

struct MovieDetails: View {
    var movie: Movie

    @State private var dispatchingSearch: Bool = false
    @State private var descriptionTruncated = true
    @State private var fileSheet: MediaFile?

    @EnvironmentObject var settings: AppSettings

    @Environment(RadarrInstance.self) private var instance
    @Environment(\.deviceType) var deviceType
    @Environment(\.openURL) var openURL

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

            if deviceType == .phone {
                actions
                    .padding(.bottom)
            }

            if movie.exists {
                information
                    .padding(.bottom)
            }
        }
    }

    var hasDescription: Bool {
        !(movie.overview ?? "").trimmed().isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(movie.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.snappy) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = deviceType == .phone
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            MediaDetailsRow(String(localized: "Status"), value: "\(movie.status.label)")

            if let studio = movie.studio, !studio.isEmpty {
                MediaDetailsRow(
                    String(localized: "Studio", comment: "The studio that produces the movie"),
                    value: studio
                )
            }

            if !movie.genres.isEmpty {
                MediaDetailsRow(String(localized: "Genre"), value: movie.genreLabel)
            }

            if movie.isDownloaded {
                Group {
                    MediaDetailsRow(String(localized: "Video"), value: mediaDetailsVideoQuality(movie.movieFile))
                    MediaDetailsRow(String(localized: "Audio"), value: mediaDetailsAudioQuality(movie.movieFile))

                    if let subtitles = mediaDetailsSubtitles(movie.movieFile, deviceType) {
                        MediaDetailsRow(String(localized: "Subtitles"), value: subtitles)
                    }
                }.onTapGesture {
                    fileSheet = movie.movieFile
                }
            }
        }
        .sheet(item: $fileSheet) { file in
            MediaFileSheet(file: file, runtime: movie.runtime)
                .presentationDetents([.fraction(0.9)])
        }
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            if movie.exists {
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
                Task { await dispatchSearch() }
            } label: {
                ButtonLabel(
                    text: "Automatic",
                    icon: "magnifyingglass",
                    isLoading: dispatchingSearch
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.movies.isWorking)
            .onAppear(perform: triggerTipIfJustAdded)
            .popoverTip(NoAutomaticSearchTip())

            NavigationLink(value: MoviesPath.releases(movie.id)) {
                ButtonLabel(text: "Interactive", icon: "person.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    var previewActions: some View {
        Group {
            Menu {
                MovieLinks(movie: movie)
            } label: {
                ButtonLabel(text: "Open In...", icon: "arrow.up.right.square")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            if let trailerUrl = MovieLinks.youTubeTrailer(movie.youTubeTrailerId) {
                Button {
                    openURL(trailerUrl)
                } label: {
                    let label: LocalizedStringKey = deviceType == .phone ? "Trailer" : "Watch Trailer"

                    ButtonLabel(text: label, icon: "play.fill")
                        .modifier(MediaPreviewActionModifier())
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else {
                Spacer()
                    .modifier(MediaPreviewActionSpacerModifier())
            }
        }
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    func triggerTipIfJustAdded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if movie.added.timeIntervalSinceNow > -30 {
                Task {
                    await NoAutomaticSearchTip.mediaAdded.donate()
                }
            }
        }
    }

    func dispatchSearch() async {
        defer { dispatchingSearch = false }
        dispatchingSearch = true

        guard await instance.movies.command(
            .search([movie.id])
        ) else {
            return
        }

        dependencies.toast.show(.movieSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "movie"])
        maybeAskForReview()
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    return MovieView(movie: Binding(get: { movie }, set: { _ in }))
        .withRadarrInstance(movies: movies)
        .withAppState()
}

#Preview("Preview") {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies[4]

    return MovieView(movie: Binding(get: { movie }, set: { _ in }))
        .withRadarrInstance(movies: movies)
        .withAppState()
}
