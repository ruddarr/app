import SwiftUI

struct AudioMediaFileSheet: View {
    var file: AlbumTrackFile
    var runtime: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private
        var reduceTransparency

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
                    String(
                        localized: "Score",
                        comment: "Custom score of media file"
                    ),
                    file.scoreLabel
                )

                if let formats = file.customFormatsList {
                    Divider()
                    row(
                        String(
                            localized: "Custom Formats",
                            comment: "Custom formats of media file"
                        ),
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
                        String(
                            localized: "Codec",
                            comment: "Audio/video codec"
                        ),
                        media.audioCodec ?? "--"
                    )

                    if let audioChannels = media.audioChannels {
                        Divider()
                        row(
                            String(
                                localized: "Channels",
                                comment: "Audio channel count"
                            ),
                            "\(audioChannels)"
                        )
                    }

                    if let bitrate = media.audioBitRate {
                        Divider()
                        row(
                            String(
                                localized: "Bitrate",
                                comment: "Audio/video bitrate"
                            ),
                            bitrate
                        )
                    }

                    if let bitDepth = media.audioBits {
                        Divider()
                        row(
                            String(
                                localized: "Bit Depth",
                                comment: "Audio bit depth"
                            ),
                            bitDepth
                        )
                    }

                    if let sampleRate = media.audioSampleRate {
                        Divider()
                        row(
                            String(
                                localized: "Sample Rate",
                                comment: "Audio sample rate"
                            ),
                            sampleRate
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

#Preview {
    let trackFiles: [AlbumTrackFile] = PreviewData.load(
        name: "album-track-files"
    )
    let files = trackFiles.filter { $0.albumId == 1_144 }
    let file = files.first ?? trackFiles[0]

    Text(verbatim: "Hello")
        .sheet(isPresented: .constant(true)) {
            AudioMediaFileSheet(file: file, runtime: 42)
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(.sheetBackground)
        }
}
