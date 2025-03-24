import SwiftUI
import TelemetryDeck

struct SeriesReleaseSheet: View {
    @State var release: SeriesRelease
    var seriesId: Series.ID
    var seasonId: Season.ID?
    var episodeId: Episode.ID?

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @State private var showGrabConfirmation: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)
                        .padding(.trailing, 40)

                    if !release.rejections.isEmpty {
                        rejectionReasons
                            .padding(.bottom)
                    }

                    actions
                        .padding(.bottom)

                    details
                        .padding(.bottom)
                }
                .padding(.top)
                .viewPadding(.horizontal)
            }
            .alert(
                isPresented: instance.series.errorBinding,
                error: instance.series.error
            ) { _ in
                Button("OK") { instance.series.error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .alert(
                "Grab Release",
                isPresented: $showGrabConfirmation
            ) {
                Button("Grab Release") { Task { await downloadRelease(force: true) } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The release for this series/episode could not be determined and it may not import automatically. Do you want to grab \"\(release.title)\"?")
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading) {
            if !flags().isEmpty {
                HStack {
                    ForEach(flags(), id: \.self) { flag in
                        Text(flag).textCase(.uppercase)
                    }
                }
                .font(.footnote)
                .fontWeight(.semibold)
                .tracking(1.1)
                .foregroundStyle(settings.theme.tint)
            }

            Text(release.title)
                .font(.title2.bold())
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)
                Bullet()
                Text(release.ageLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            CustomFormats(tags())
        }
    }

    var rejectionReasons: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle").symbolVariant(.fill)
                Text("Release Rejected")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 7)
            .font(.footnote)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .kerning(0.2)
            .background(.yellow)
            .foregroundStyle(.black)

            VStack(alignment: .leading) {
                ForEach(release.rejections, id: \.self) { rejection in
                    Text(rejection)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var actions: some View {
        HStack(spacing: 24) {
            if deviceType != .phone {
                Spacer()
            }

            if let url = URL(string: release.infoUrl ?? "") {
                Link(destination: url, label: {
                    let label: LocalizedStringKey = deviceType == .phone ? "Website" : "Open Website"

                    ButtonLabel(text: label, icon: "arrow.up.right.square")
                        .modifier(MediaPreviewActionModifier())
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
                .contextMenu {
                    LinkContextMenu(url)
                }
            }

            Button {
                if release.downloadAllowed {
                    Task { await downloadRelease() }
                } else {
                    showGrabConfirmation = true
                }
            } label: {
                let label: LocalizedStringKey = deviceType == .phone ? "Download" : "Download Release"

                ButtonLabel(
                    text: label,
                    icon: "arrow.down.circle",
                    isLoading: instance.series.isWorking
                )
                .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.series.isWorking)

            if deviceType != .phone {
                Spacer()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var details: some View {
        Section {
            VStack(spacing: 6) {
                row("Language", value: release.languagesLabel)
                Divider()

                row("Bitrate", value: release.bitrateLabel(runtime) ?? "--")
                Divider()

                row("Indexer", value: release.indexerLabel)

                if release.isTorrent {
                    Divider()
                    row("Peers", value: String(
                        format: "S: %i  L: %i",
                        release.seeders ?? 0,
                        release.leechers ?? 0
                    ))
                }
            }
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    var runtime: Int {
        guard let episodeNumbers = release.mappedEpisodeNumbers else {
            return 0
        }

        let seriesRuntime: Int = instance.series.byId(seriesId)?.runtime ?? 0

        let episodes: [Int] = episodeNumbers.map { id in
            instance.episodes.byId(id)?.runtime ?? seriesRuntime
        }

        return episodes.reduce(0, +)
    }

    func flags() -> [String] {
        var flags: [String] = []

        let indexerFlags = release.releaseFlags

        if !indexerFlags.isEmpty {
            flags.append(contentsOf: indexerFlags.map { $0.label })
        }

        if release.isProper {
            flags.append(String(localized: "Proper"))
        }

        if release.isRepack {
            flags.append(String(localized: "Repack"))
        }

        return flags
    }

    func tags() -> [String] {
        var tags: [String] = []

        if let score = release.scoreLabel, release.customFormatScore != 0 {
            tags.append(score)
        }

        if let formats = release.customFormats, !formats.isEmpty {
            tags.append(contentsOf: formats.map { $0.label })
        }

        return tags
    }

    func row(_ label: LocalizedStringKey, value: String) -> some View {
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
        .padding(.vertical, 6)
    }

    func downloadRelease(force: Bool = false) async {
        guard await instance.series.download(
            guid: release.guid,
            indexerId: release.indexerId,
            seriesId: force && episodeId != nil ? seriesId : nil,
            seasonId: force && episodeId != nil ? seasonId : nil,
            episodeId: force && episodeId != nil ? episodeId : nil
        ) else {
            return
        }

        dismiss()
        dependencies.router.seriesPath.removeLast()
        dependencies.toast.show(.downloadQueued)

        TelemetryDeck.signal("releaseDownloaded", parameters: ["type": release.fullSeason ? "season" : "episode"])
        maybeAskForReview()
    }
}

#Preview {
    let releases: [SeriesRelease] = PreviewData.load(name: "series-releases")
    let release = releases[5]

    return SeriesReleaseSheet(
        release: release,
        seriesId: release.seriesId ?? 0
    )
        .withAppState()
}
