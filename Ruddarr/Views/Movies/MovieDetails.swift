import SwiftUI

struct MovieDetails: View {
    var movie: Movie

    @State private var isTruncated = true

    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        VStack {
            // MARK: overview
            HStack(alignment: .top) {
                CachedAsyncImage(url: movie.remotePoster)
                    .scaledToFit()
                    .frame(height: 195)
                    .clipped()
                    .cornerRadius(8)
                    .padding(.trailing, 8)

                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .kerning(-0.5)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Text(movie.certification ?? "test")
                                .padding(.horizontal, 4)
                                .border(.secondary)

                            Text(String(movie.year))

                            Text(movie.humanRuntime)
                        }
                        .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                            Text(movie.monitored ? "Monitored" : "Unmonitored")
                        }

                        // tvdb, imdb, rotten 2x

                        //                        HStack(spacing: 12) {
                        //                            Text(String(movie.year))
                        //                            Text(movie.humanRuntime)
                        //                        }
                        //                        .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.bottom)

            // MARK: description
            HStack(alignment: .top) {
                Text(movie.overview!)
                    .font(.callout)
                    .lineLimit(isTruncated ? 4 : nil)
                    .onTapGesture { isTruncated = false }

                Spacer()
            }
            .padding(.bottom)

            // MARK: details
            Grid(alignment: .leading) {
                detailsRow("Status", value: movie.status.label)

                detailsRow("Studio", value: movie.studio!)

                if !movie.genres.isEmpty {
                    detailsRow("Genre", value: movie.humanGenres)
                }

                detailsRow("Video", value: videoQuality)
                detailsRow("Audio", value: audioQuality)
            }.padding(.bottom)

            // MARK: actions
            HStack(spacing: 24) {
                Button(action: { }) {
                    Label("Automatic", systemImage: "magnifyingglass")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(action: { }) {
                    Label("Interactive", systemImage: "magnifyingglass")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom)

            // MARK: ...
            Grid(alignment: .leading) {
                detailsRow("Path?", value: "")
                detailsRow("Root Folder", value: "")
                detailsRow("minimum Availability", value: "")
                detailsRow("Quality Profile", value: qualityProfile)

                if movie.sizeOnDisk != nil {
                    detailsRow("Size", value: movie.humanSize)
                }
            }
            .border(.gray)
            .padding(.bottom)

            // MARK: ...
            Grid(alignment: .leading) {
                if let inCinemas = movie.inCinemas {
                    detailsRow("In Cinemas", value: inCinemas.formatted(.dateTime.day().month().year()))
                }

                detailsRow("Physical Release", value: "")
                detailsRow("Digital Release", value: "")
            }
            .border(.gray)


            Section("test") {
                LabeledContent("Physical Release") {
                    Text("test")
                }
                //                Text("Physical Release")
                //                    .textCase(.uppercase)
                //                    .foregroundStyle(.secondary)
                //                    .fontWeight(.medium)
                //                    .padding(.trailing)
                //                Text("test")
                //                Spacer()
            }.border(.red)
                .frame(minHeight: 100)
            //            SidebarListStyle
        }
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
            languages = langs.filter{ $0.name != nil }.map{ $0.name ?? "Unknown" }
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
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    return MovieSearchSheet(movie: movies[1])
        .withAppState()
}
