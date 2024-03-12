import SwiftUI

struct MovieDetails: View {
    var movie: Movie

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    let smallScreen = UIDevice.current.userInterfaceIdiom == .phone

    var body: some View {
        VStack(alignment: .leading) {
            detailsOverview
                .padding(.bottom)

            if hasDescription {
                description
                    .padding(.bottom)
            }

            detailsGrid
                .padding(.bottom)

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
                    withAnimation { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = smallScreen
        }
    }

    var detailsGrid: some View {
        Grid(alignment: .leading) {
            if let studio = movie.studio, !studio.isEmpty {
                detailsRow(String(localized: "Studio"), value: studio)
            }

            if !movie.genres.isEmpty {
                detailsRow(String(localized: "Genre"), value: movie.genreLabel)
            }

            detailsRow(String(localized: "Status"), value: movie.status.label)

            if movie.isDownloaded {
                detailsRow(String(localized: "Video"), value: videoQuality)
                detailsRow(String(localized: "Audio"), value: audioQuality)

                if let languages = subtitles {
                    detailsRow(String(localized: "Subtitles"), value: languages)
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
                ButtonLabel(text: String(localized: "Automatic"), icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.movies.isWorking)

            NavigationLink(value: MoviesView.Path.releases(movie.id), label: {
                ButtonLabel(text: String(localized: "Interactive"), icon: "person.fill")
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
                ButtonLabel(text: String(localized: "Open In..."), icon: "arrow.up.right.square")
                    .modifier(MoviePreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            if let trailerUrl = MovieContextMenu.youTubeTrailer(movie.youTubeTrailerId) {
                Button {
                    UIApplication.shared.open(URL(string: trailerUrl)!)
                } label: {
                    let label = smallScreen
                        ? String(localized: "Trailer")
                        : String(localized: "Watch Trailer")

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

            if let dynamicRange = movie.movieFile?.mediaInfo.videoDynamicRange, !dynamicRange.isEmpty {
                label += " \(dynamicRange)"
            }
        }

        if let videoCodec = movie.movieFile?.mediaInfo.videoCodec {
            codec = videoCodec
            codec = codec.replacingOccurrences(of: "x264", with: "H264")
            codec = codec.replacingOccurrences(of: "h264", with: "H264")
            codec = codec.replacingOccurrences(of: "h265", with: "HEVC")
            codec = codec.replacingOccurrences(of: "x265", with: "HEVC")
        }

        if label.isEmpty {
            label = String(localized: "Unknown")
        }

        return "\(label) (\(codec))"
    }

    var audioQuality: String {
        var languages: [String] = []
        var codec = ""

        if let langs = movie.movieFile?.languages {
            languages = langs
                .filter { $0.name != nil }
                .map { $0.name ?? String(localized: "Unknown") }
        }

        if let audioCodec = movie.movieFile?.mediaInfo.audioCodec {
            codec = audioCodec

            if let channels = movie.movieFile?.mediaInfo.audioChannels {
                codec += " " + String(channels)
            }
        }

        if languages.isEmpty {
            languages.append(String(localized: "Unknown"))
        }

        let languageList = languages.formatted(.list(type: .and, width: .narrow))

        return "\(languageList) (\(codec))"
    }

    var subtitles: String? {
        guard let codes = movie.movieFile?.mediaInfo.subtitleCodes else {
            return nil
        }

        if codes.count > 6 {
            var someCodes = Array(codes.prefix(4)).map {
                $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
            }

            someCodes.append(
                String(format: String(localized: "+%d more..."), codes.count - 4)
            )

            return someCodes.formatted(.list(type: .and, width: .narrow))
        }

        return codes.map {
            $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
        }.formatted(.list(type: .and, width: .narrow))
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    func detailsRow(_ label: String, value: String) -> some View {
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

struct MoviePreviewActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: 215)
        }
    }
}
