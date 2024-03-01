import SwiftUI

struct MovieDetails: View {
    var movie: Movie

    @State private var descriptionTruncated = UIDevice.current.userInterfaceIdiom == .phone ? true : false

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        VStack(alignment: .leading) {
            detailsOverview
                .padding(.bottom)

            description
                .padding(.bottom)

            Grid(alignment: .leading) {
                if let studio = movie.studio, !studio.isEmpty {
                    detailsRow("Studio", value: studio)
                }

                if !movie.genres.isEmpty {
                    detailsRow("Genre", value: movie.genreLabel)
                }

                detailsRow("Status", value: movie.status.label)

                if movie.isDownloaded {
                    detailsRow("Video", value: videoQuality)
                    detailsRow("Audio", value: audioQuality)

                    if let languages = subtitles {
                        detailsRow("Subtitles", value: languages)
                    }
                }
            }.padding(.bottom)

            if UIDevice.current.userInterfaceIdiom == .phone {
                actions
                    .padding(.bottom)
            }

            information
                .padding(.bottom)
        }
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(movie.overview!)
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation { descriptionTruncated = false }
                }

            Spacer()
        }
    }

    var actions: some View {
        HStack(spacing: 24) {
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
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
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
            label = "Unknown"
        }

        return "\(label) (\(codec))"
    }

    var audioQuality: String {
        var languages: [String] = []
        var codec = ""

        if let langs = movie.movieFile?.languages {
            languages = langs
                .filter { $0.name != nil }
                .map { $0.name ?? "Unknown" }
        }

        if let audioCodec = movie.movieFile?.mediaInfo.audioCodec {
            codec = audioCodec

            if let channels = movie.movieFile?.mediaInfo.audioChannels {
                codec += " " + String(channels)
            }
        }

        if languages.isEmpty {
            languages.append("Unknown")
        }

        let languageList = languages.joined(separator: ", ")

        return "\(languageList) (\(codec))"
    }

    var subtitles: String? {
        guard let codes = movie.movieFile?.mediaInfo.subtitleCodes else {
            return nil
        }

        if codes.count > 6 {
            return Array(codes.prefix(4)).map {
                $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
            }.joined(separator: ", ") + ", +\(codes.count - 4) more..."
        }

        return codes.map {
            $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
        }.joined(separator: ", ")
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
        )?.name ?? "Unknown"
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

    return MovieSearchSheet(movie: movie)
        .withSettings()
        .withRadarrInstance(movies: movies)
}
