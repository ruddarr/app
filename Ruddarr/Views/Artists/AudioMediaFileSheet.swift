import SwiftUI

struct AudioMediaFileSheet: View {
    var file: AlbumTrackFile
    var runtime: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    generalMetadata
                    audioMetadata

                    Spacer().frame(height: 42)
                }
                .padding(.top, reduceTransparency ? 0 : -52)
                .scenePadding(.horizontal)
            }
            #if os(macOS)
                .padding(.bottom)
            #endif
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .hideIconOnMac()
                    .tint(.primary)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    var generalMetadata: some View {
        Section {
            VStack(spacing: 6) {
                if let dateAdded = file.dateAdded {
                    row(
                        String(localized: "Added"),
                        dateAdded.formatted(date: .long, time: .shortened)
                    )
                }
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
    var audioMetadata: some View {
        if let media = file.mediaInfo {
            // swiftlint:disable closure_body_length
            Section {
                VStack(spacing: 6) {
                    row(
                        String(localized: "Codec", comment: "Audio/video codec"),
                        media.audioCodec ?? "--"
                    )
                    if let audioChannels = media.audioChannels {
                        Divider()
                        row(
                            String(localized: "Channels", comment: "Audio channel count"),
                            "\(audioChannels)"
                        )
                    }
                    Divider()
                    row(
                        String(localized: "Bitrate", comment: "Audio/video bitrate"),
                        formatBitrate(media.audioBitrate) ?? "--"
                    )
                    if let audioStreamCount = media.audioStreamCount {
                        Divider()
                        row(
                            String(localized: "Streams", comment: "Audio stream count"),
                            "\(audioStreamCount)"
                        )
                    }

                    if let codes = media.audioLanguageCodes {
                        Divider()
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
        // swiftlint:enable closure_body_length
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
