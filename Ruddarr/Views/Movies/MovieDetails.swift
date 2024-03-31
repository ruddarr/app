import SwiftUI

struct MovieDetails: View {
    var movie: Movie

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

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

            if movie.exists {
                information
                    .padding(.bottom)
            }
        }
    }

    var hasDescription: Bool {
        !(movie.overview ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(movie.overview ?? "")
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
            detailsRow("Status", value: "\(movie.status.label)")

            if let studio = movie.studio, !studio.isEmpty {
                detailsRow("Studio", value: studio)
            }

            if !movie.genres.isEmpty {
                detailsRow("Genre", value: movie.genreLabel)
            }

            if movie.isDownloaded {
                detailsRow("Video", value: videoQuality)
                detailsRow("Audio", value: audioQuality)

                if let languages = subtitles {
                    detailsRow("Subtitles", value: languages)
                }
            }
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
                Task { @MainActor in
                    guard await instance.movies.command(movie, command: .automaticSearch) else {
                        return
                    }

                    dependencies.toast.show(.searchQueued)
                }
            } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.movies.isWorking)

            NavigationLink(value: MoviesView.Path.releases(movie.id), label: {
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
                MovieContextMenu(movie: movie)
            } label: {
                ButtonLabel(text: "Open In...", icon: "arrow.up.right.square")
                    .modifier(MoviePreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            if let trailerUrl = MovieContextMenu.youTubeTrailer(movie.youTubeTrailerId) {
                Button {
                    UIApplication.shared.open(URL(string: trailerUrl)!)
                } label: {
                    let label: LocalizedStringKey = smallScreen ? "Trailer" : "Watch Trailer"

                    ButtonLabel(text: label, icon: "play.fill")
                        .modifier(MoviePreviewActionModifier())
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else if !smallScreen {
                 Spacer()
            }
        }
    }

    var videoQuality: String {
        var label = ""
        var codec = ""

        if let resolution = movie.movieFile?.quality.quality.resolution {
            label = "\(resolution)p"
            label = label.replacingOccurrences(of: "2160p", with: "4K")
            label = label.replacingOccurrences(of: "4320p", with: "8K")

            if let dynamicRange = movie.movieFile?.mediaInfo?.videoDynamicRange, !dynamicRange.isEmpty {
                label += " \(dynamicRange)"
            }
        }

        if let videoCodecLabel = movie.movieFile?.mediaInfo?.videoCodecLabel {
            codec = videoCodecLabel
        }

        if label.isEmpty {
            label = String(localized: "Unknown")
        }

        return codec.isEmpty ? "\(label)" : "\(label) (\(codec))"
    }

    var audioQuality: String {
        var languages: [String] = []
        var codec = ""

        if let langs = movie.movieFile?.languages {
            languages = langs
                .filter { $0.name != nil }
                .map { $0.label }
        }

        if let audioCodec = movie.movieFile?.mediaInfo?.audioCodec {
            codec = audioCodec

            if let channels = movie.movieFile?.mediaInfo?.audioChannels {
                codec += " \(channels)"
            }
        }

        if languages.isEmpty {
            languages.append(String(localized: "Unknown"))
        }

        let languageList = languages.formatted(.list(type: .and, width: .narrow))

        return codec.isEmpty ? "\(languageList)" : "\(languageList) (\(codec))"
    }

    var subtitles: String? {
        guard let codes = movie.movieFile?.mediaInfo?.subtitleCodes else {
            return nil
        }

        if codes.count > 1 {
            var someCodes = Array(codes.prefix(2)).map {
                $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
            }

            someCodes.append(
                String(format: String(localized: "+%d more..."), codes.count - 2)
            )

            return someCodes.formatted(.list(type: .and, width: .narrow))
        }

        return languagesList(codes)
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
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

struct MoviePreviewActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: 215)
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    return MovieView(movie: Binding(get: { movie }, set: { _ in }))
        .withSettings()
        .withRadarrInstance(movies: movies)
}

#Preview("Preview") {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    return MovieView(movie: Binding(get: { movie }, set: { _ in }))
        .withSettings()
        .withRadarrInstance(movies: movies)
}
