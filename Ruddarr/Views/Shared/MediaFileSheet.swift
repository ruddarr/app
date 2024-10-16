import SwiftUI

struct MediaFileSheet: View {
    var file: MediaFile

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
                    row("Custom Formats", formats.formattedList())
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
                            Text(languagesList(codes))
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                            Text(languagesList(codes))
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
