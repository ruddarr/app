import SwiftUI

struct MovieHistoryEventSheet: View {
    var event: MovieHistoryEvent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            VStack(alignment: .leading) {
                Text(event.eventType.title)
                    .font(.title3.bold())

                Text(formatDate(event.date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                Text(event.description)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom)

                if event.eventType == .grabbed {
                    grabbedDetails
                }

                Spacer()
            }
            .viewPadding(.horizontal)
            .padding(.top)
        }
    }

    @ViewBuilder
    var grabbedDetails: some View {
        if event.eventType == .grabbed {
            VStack(spacing: 6) {
                row("Source", event.data("releaseSource") ?? "--")
                Divider()
                row("Match Type", event.data("movieMatchType") ?? "--")

                if let string = event.data("publishedDate"), let date = parseDate(string) {
                    Divider()
                    row("Published", formatDate(date))
                }

                if let string = event.data("nzbInfoUrl"), let url = URL(string: string), let domain = url.host {
                    Divider()
                    renderRow("URL", Link(domain, destination: url))
                }

                if let flags = event.indexerFlagsLabel {
                    Divider()
                    row("Flags", flags)
                }

                if let score = event.scoreLabel {
                    Divider()
                    row("Score", score)
                }

                if !event.customFormats.isEmpty  {
                    Divider()
                    row("Custom Formats", event.customFormats.map { $0.label }.formatted(.list(type: .and, width: .narrow)))
                }

                if let group = event.data("releaseGroup") {
                    Divider()
                    row("Release Group", group)
                }
            }
        }
    }

    func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        renderRow(label, Text(value).foregroundStyle(.primary))
    }

    func renderRow<V: View>(_ label: LocalizedStringKey, _ value: V) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
            Spacer()
            value
        }
        .font(.subheadline)
    }

    func parseDate(_ string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }

        return nil
    }

    func formatDate(_ date: Date) -> String {
        date.formatted(date: .long, time: .shortened)
    }
}

struct MovieFileSheet: View {
    var file: MovieFile

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            Group {
                generalMetadata
                videoMetadata
                audioMetadata
            }
            .viewPadding(.horizontal)
            .overlay(alignment: .topTrailing) {
                CloseButton {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    var generalMetadata: some View {
        Section {
            VStack(spacing: 6) {
                row("Added", file.dateAdded.formatted(date: .long, time: .shortened))
                Divider()
                row("Score", file.scoreLabel)

                if let formats = file.customFormatsList {
                    Divider()
                    row("Custom Formats", formats.formatted(.list(type: .and, width: .narrow)))
                }
            }
        } header: {
            headline("Information")
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    var videoMetadata: some View {
        if let media = file.mediaInfo {
            Section {
                VStack(spacing: 6) {
                    row("Codec", media.videoCodecLabel ?? "--")
                    Divider()
                    row("Dynamic Range", media.videoDynamicRangeLabel ?? "--")
                    Divider()
                    row("Runtime", media.runTime ?? "--")
                    Divider()
                    row("Resolution", media.resolution?.replacingOccurrences(of: "x", with: " × ") ?? "--")
                    Divider()
                    row("Frame Rate", String(format: "%.0f fps", media.videoFps))
                    Divider()
                    row("Bitrate", bitrate(media.videoBitrate) ?? "--")
                    Divider()
                    row("Bit Depth", "\(media.videoBitDepth)")
                    Divider()
                    row("Scan Type", media.scanType ?? "--")
                    Divider()

                    if let codes = media.subtitleCodes {
                        row("Subtitles", codes.count <= 3 ? languagesList(codes) : "")

                        if codes.count > 3 {
                            Text(languagesList(codes)).foregroundStyle(.primary).font(.subheadline)
                        }
                    } else {
                        row("Subtitles", "--")
                    }
                }
            } header: {
                headline("Video")
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    var audioMetadata: some View {
        if let media = file.mediaInfo {
            Section {
                VStack(spacing: 6) {
                    row("Codec", media.audioCodec ?? "--")
                    Divider()
                    row("Channels", "\(media.audioChannels)")
                    Divider()
                    row("Bitrate", bitrate(media.audioBitrate) ?? "--")
                    Divider()
                    row("Streams", "\(media.audioStreamCount)")
                    Divider()
                    if let codes = media.audioLanguageCodes {
                        row("Languages", codes.count <= 3 ? languagesList(codes) : "")

                        if codes.count > 3 {
                            Text(languagesList(codes)).foregroundStyle(.primary).font(.subheadline)
                        }
                    } else {
                        row("Languages", "--")
                    }
                }
            } header: {
                headline("Audio")
                    .padding(.bottom, 4)
            }
        }
    }

    func headline(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title2.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top)
    }

    func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
            Spacer()
            Text(value)
                .foregroundStyle(.primary)

        }
        .font(.subheadline)
    }

    func bitrate(_ bitrate: Int) -> String? {
        if bitrate == 0 {
            return nil
        }

        if bitrate < 1_000_000 {
            return String(format: "%d kbps", bitrate / 1_000)
        }

        return String(format: "%d mbps", bitrate / 1_000_000)
    }
}

#Preview("File") {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 295 }) ?? movies[0]

    return MovieFileSheet(file: movie.movieFile!)
}

#Preview("Event") {
    let events: [MovieHistoryEvent] = PreviewData.load(name: "movie-history")

    return MovieHistoryEventSheet(event: events[1])
}
