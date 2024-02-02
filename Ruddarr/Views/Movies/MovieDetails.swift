import SwiftUI

struct MovieDetails: View {
    var movie: Movie

    @State private var isTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        VStack(alignment: .leading) {
            // MARK: overview
            MovieDetailsOverview(movie: movie)
                .padding(.bottom)

            // MARK: description
            HStack(alignment: .top) {
                Text(movie.overview!)
                    .font(.callout)
                    .transition(.slide)
                    .lineLimit(isTruncated ? 4 : nil)
                    .onTapGesture {
                        withAnimation { isTruncated.toggle() }
                    }

                Spacer()
            }
            .padding(.bottom)

            // MARK: details
            Grid(alignment: .leading) {
                detailsRow("Status", value: movie.status.label)

                if (movie.studio?.isEmpty) != nil {
                    detailsRow("Studio", value: movie.studio!)
                }

                if !movie.genres.isEmpty {
                    detailsRow("Genre", value: movie.humanGenres)
                }

                if movie.hasFile {
                    detailsRow("Video", value: videoQuality)
                    detailsRow("Audio", value: audioQuality)
                }
            }.padding(.bottom)

            // MARK: actions
            actions
                .padding(.bottom)

            // MARK: information
            information
                .padding(.bottom)

            // TODO: Files? Cast? History?
        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            Button {
                // TODO: needs action
            } label: {
                Label("Automatic", systemImage: "magnifyingglass")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(settings.theme.tint)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .frame(maxWidth: .infinity)

            NavigationLink(value: MoviesView.Path.releases(movie.id), label: {
                Label("Interactive", systemImage: "person.fill")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(settings.theme.tint)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.bordered)
            .tint(.secondary)
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var information: some View {
        Section(
            header: Text("Information")
                .font(.title2)
                .fontWeight(.bold)
        ) {
            VStack(spacing: 12) {
                informationRow("Quality Profile", value: qualityProfile)
                Divider()
                informationRow("Minimum Availability", value: movie.minimumAvailability.label)
                Divider()
                informationRow("Root Folder", value: movie.rootFolderPath ?? "")

                if movie.hasFile {
                    Divider()
                    informationRow("Size", value: movie.sizeOnDisk == nil ? "" : movie.humanSize)
                }

                if let inCinemas = movie.inCinemas {
                    Divider()
                    informationRow("In Cinemas", value: inCinemas.formatted(.dateTime.day().month().year()))
                }

                if let physicalRelease = movie.physicalRelease {
                    Divider()
                    informationRow("Physical Release", value: physicalRelease.formatted(.dateTime.day().month().year()))
                }

                if let digitalRelease = movie.digitalRelease {
                    Divider()
                    informationRow("Digital Release", value: digitalRelease.formatted(.dateTime.day().month().year()))
                }
            }
        }
        .font(.callout)
    }

    var videoQuality: String {
        var label = ""
        var codec = ""

        if let resolution = movie.movieFile?.quality.quality.resolution {
            label = "\(resolution)p"
        }

        if let videoCodec = movie.movieFile?.mediaInfo.videoCodec {
            codec = videoCodec
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
        }

        if languages.isEmpty {
            languages.append("Unknown")
        }

        let languageList = languages.joined(separator: ", ")

        return "\(languageList) (\(codec))"
    }

    var qualityProfile: String {
        return instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
        )?.name ?? "Unknown"
    }

    func detailsRow(_ label: String, value: String) -> some View {
        GridRow {
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

    func informationRow(_ label: String, value: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.primary)
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
    }
}

struct MovieDetailsOverview: View {
    var movie: Movie

    var body: some View {
        HStack(alignment: .top) {
            CachedAsyncImage(url: movie.remotePoster, type: .poster)
                .scaledToFit()
                .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 1)
                .clipped()
                .cornerRadius(8)
                .padding(.trailing, 8)

            Group {
                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .kerning(-0.5)
                        .lineLimit(3)

                    HStack(spacing: 6) {
                        Text(String(movie.year))
                        Text("•")
                        Text(movie.humanRuntime)

                        if movie.certification != nil {
                            Text("•")
                            Text(movie.certification ?? "")
                        }
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        if let rating = movie.ratings?.rottenTomatoes?.value {
                            HStack(spacing: 6) {
                                Image("rotten").resizable()
                                    .scaledToFit()
                                    .frame(height: 14)

                                Text(String(format: "%.0f%%", rating))
                            }
                        }

                        if let rating = movie.ratings?.imdb?.value {
                            HStack(spacing: 6) {
                                Image("imdb").resizable()
                                    .scaledToFit()
                                    .frame(height: 12)

                                Text(String(format: "%.1f", rating))
                            }
                        }

                        // TODO: more ratings
                        // tvdb (only 2-3 at a time)
                        // metric critic (only last?)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    // TODO: Show status on poster?

                    // Downloaded
                    // Missing
                }
            }

            Spacer()
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    return MovieSearchSheet(movie: movies[232])
        .withAppState()
}
