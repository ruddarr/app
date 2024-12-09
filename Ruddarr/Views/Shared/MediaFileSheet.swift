import SwiftUI

struct MediaFileSheet: View {
    var file: MediaFile
    var runtime: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            Group {
                generalMetadata
                videoMetadata
                audioMetadata
                textMetadata
            }
            .viewPadding(.horizontal)
            .overlay(alignment: .topTrailing) {
                CloseButton {
                    dismiss()
                }
            }
        }
        #if os(macOS)
            .padding(.bottom)
        #endif
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
                    row("Runtime", media.runTime ?? "--")
                    Divider()
                    row("Resolution", media.resolution?.replacingOccurrences(of: "x", with: "×") ?? "--")
                    Divider()
                    row("Codec", media.videoCodecLabel ?? "--")
                    Divider()

                    if let dynamicRange = media.videoDynamicRangeLabel {
                        row("Dynamic Range", dynamicRange)
                        Divider()
                    }

                    row("Bitrate", file.videoBitrateLabel(runtime) ?? "--")
                    Divider()
                    row("Framerate", String(format: "%.0f fps", media.videoFps))
                    Divider()
                    row("Color Depth", "\(media.videoBitDepth) bit")
                    Divider()
                    row("Scan Type", media.scanType ?? "--")
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
                    row("Bitrate", formatBitrate(media.audioBitrate) ?? "--")
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

    @ViewBuilder
    var textMetadata: some View {
        if let media = file.mediaInfo, let codes = media.subtitleCodes {
            Section {
                VStack(spacing: 6) {
                    row("Languages", codes.count <= 3 ? languagesList(codes) : "")

                    if codes.count > 3 {
                        Text(languagesList(codes))
                            .foregroundStyle(.primary)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } header: {
                headline("Subtitles")
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
}
