import SwiftUI

struct BookFileSheet: View {
    var file: BookFile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    generalMetadata
                    audioMetadata

                    Spacer().frame(height: 42)
                }
                .padding(.top, deviceType == .mac ? 24 : (reduceTransparency ? 0 : -52))
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
                    String(localized: "Quality"),
                    file.quality.quality.label
                )

                if let mediaType = file.mediaType, !mediaType.isEmpty {
                    Divider()
                    row(
                        String(localized: "Format", comment: "Audiobook or eBook"),
                        mediaType.capitalized
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
        if let media = file.mediaInfo, media.hasAudio {
            Section {
                VStack(spacing: 6) {
                    row(
                        String(localized: "Codec", comment: "Audio/video codec"),
                        value(media.audioCodec)
                    )
                    Divider()
                    row(
                        String(localized: "Bitrate", comment: "Audio/video bitrate"),
                        value(media.audioBitRate)
                    )
                    Divider()
                    row(
                        String(localized: "Channels", comment: "Audio channel count"),
                        media.audioChannels.map { "\($0)" } ?? "--"
                    )
                    Divider()
                    row(
                        String(localized: "Sample Rate", comment: "Audio sample rate"),
                        value(media.audioSampleRate)
                    )

                    if let bits = media.audioBits?.trimmed(), !bits.isEmpty {
                        Divider()
                        row(
                            String(localized: "Bit Depth", comment: "Audio bit depth"),
                            bits
                        )
                    }
                }
            } header: {
                headline("Audio")
                    .padding(.bottom, 4)
            }
        }
    }

    func value(_ string: String?) -> String {
        guard let string = string?.trimmed(), !string.isEmpty else { return "--" }

        return string
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
    @Previewable @State var show: Bool = false

    let files: [BookFile] = PreviewData.load(name: "book-files")

    Button {
        show.toggle()
    } label: {
        Text(verbatim: "Hello")
    }
    .sheet(isPresented: $show) {
        BookFileSheet(file: files[0])
            .presentationDetents([.medium])
            .presentationBackground(.sheetBackground)
    }
}
