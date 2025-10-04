import SwiftUI

struct MediaFileSheet: View {
    var file: MediaFile
    var runtime: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    generalMetadata
                    videoMetadata
                    audioMetadata
                    textMetadata
                }
                .viewPadding(.horizontal)
            }
            .offset(y: -30)
            #if os(macOS)
                .padding(.bottom)
            #endif
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }.tint(.primary)
                }
            }
        }
    }

    @ViewBuilder
    var generalMetadata: some View {
        Section {
            VStack(spacing: 6) {
                row(
                    String(localized: "Added"),
                    file.dateAdded.formatted(date: .long, time: .shortened)
                )
                Divider()
                row(
                    String(localized: "File Size"),
                    file.sizeLabel
                )
                Divider()
                row(
                    String(localized: "Score", comment: "Custom score of media file"),
                    file.scoreLabel
                )

                if let formats = file.customFormatsList {
                    Divider()
                    row(
                        String(localized: "Custom Formats", comment: "Custom formats of media file"),
                        formats.formattedList()
                    )
                }
            }
        } header: {
            headline("Information")
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    var videoMetadata: some View {
        // swiftlint:disable closure_body_length
        if let media = file.mediaInfo {
            Section {
                VStack(spacing: 6) {
                    row(
                        String(localized: "Runtime", comment: "Video runtime"),
                        media.runTime ?? "--"
                    )
                    Divider()
                    row(
                        String(localized: "Resolution", comment: "Video file resolution"),
                        media.resolution?.replacingOccurrences(of: "x", with: "×") ?? "--"
                    )
                    Divider()
                    row(
                        String(localized: "Codec"),
                        media.videoCodecLabel ?? "--"
                    )
                    Divider()

                    if let dynamicRange = media.videoDynamicRangeLabel {
                        row(
                            String(localized: "Dynamic Range", comment: "Video file dynamic range"),
                            dynamicRange
                        )
                        Divider()
                    }

                    row(
                        String(localized: "Bitrate"),
                        file.videoBitrateLabel(runtime) ?? "--"
                    )
                    Divider()
                    row(
                        String(localized: "Framerate", comment: "Video frame rate"),
                        String(format: "%.0f fps", media.videoFps)
                    )
                    Divider()
                    row(
                        String(localized: "Color Depth", comment: "Video color depth"),
                        "\(media.videoBitDepth) bit"
                    )
                    Divider()
                    row(
                        String(localized: "Scan Type", comment: "Video scan Type"),
                        media.scanType ?? "--"
                    )
                }
            } header: {
                headline("Video")
                    .padding(.bottom, 4)
            }
        }
        // swiftlint:enable closure_body_length
    }

    @ViewBuilder
    var audioMetadata: some View {
        if let media = file.mediaInfo {
            Section {
                VStack(spacing: 6) {
                    row(
                        String(localized: "Codec", comment: "Audio/video codec"),
                        media.audioCodec ?? "--"
                    )
                    Divider()
                    row(
                        String(localized: "Channels", comment: "Audio channel count"),
                        "\(media.audioChannels)"
                    )
                    Divider()
                    row(
                        String(localized: "Bitrate", comment: "Audio/video bitrate"),
                        formatBitrate(media.audioBitrate) ?? "--"
                    )
                    Divider()
                    row(
                        String(localized: "Streams", comment: "Audio stream count"),
                        "\(media.audioStreamCount)"
                    )
                    Divider()

                    if let codes = media.audioLanguageCodes {
                        row(
                            String(localized: "Languages"),
                            codes.count <= 3 ? languagesList(codes) : ""
                        )

                        if codes.count > 3 {
                            Text(languagesList(codes))
                                .foregroundStyle(.primary)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        row(
                            String(localized: "Languages"),
                            "--"
                        )
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
                    row(
                        String(localized: "Languages", comment: "Metadata row label"),
                        codes.count <= 3 ? languagesList(codes) : ""
                    )

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

    func row(_ label: String, _ value: String) -> some View {
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
        .padding(.vertical, 4)
    }
}
