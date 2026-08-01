import SwiftUI
import TelemetryDeck

struct SeriesReleaseSheet: View {
    var release: SeriesRelease
    var seriesId: Series.ID
    var seasonId: Season.ID?
    var episodeId: Episode.ID?

    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType
    @Environment(\.inCalendarSheet) private var inCalendarSheet
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var showGrabConfirmation: Bool = false

    var body: some View {
        // swiftlint:disable:next closure_body_length
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)

                    if !release.rejections.isEmpty {
                        rejectionReasons
                            .padding(.bottom)
                    }

                    actions
                        .padding(.bottom)

                    details
                }
                .scenePadding(.horizontal)
                .padding(.top, deviceType == .mac ? 24 : (reduceTransparency ? 0 : -45))
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .hideIconOnMac()
                    .tint(.primary)
                }
            }
            .sensoryAlert(
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
                Button("Grab Release", role: .confirm) { Task { await downloadRelease(force: true) } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The release for this series/episode could not be determined and it may not import automatically. Do you want to grab \"\(release.title)\"?")
            }
            .tint(nil)
        }
        .displayToasts()
    }

    var header: some View {
        VStack(alignment: .leading) {
            if !release.flagLabels.isEmpty {
                HStack {
                    ForEach(release.flagLabels, id: \.self) { flag in
                        Text(flag).textCase(.uppercase)
                    }
                }
                .font(.footnote)
                .fontWeight(.semibold)
                .tracking(1.1)
                .foregroundStyle(settings.theme.tint)
            }

            Text(release.title.breakable())
                .font(.title2.bold())
                .kerning(-0.5)
                .padding(.trailing, 56)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)
                Bullet()
                Text(release.ageLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            CustomFormats(release.formatLabels)
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
        .background(.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var actions: some View {
        HStack(spacing: 20) {
            if let url = URL(string: release.infoUrl ?? "") {
                Link(destination: url, label: {
                    let label: LocalizedStringKey = deviceType == .phone ? "Website" : "Open Website"

                    ButtonLabel(text: label, icon: "arrow.up.right.square")
                })
                .actionButton()
                .actionButtonWidth()
                .contextMenu {
                    LinkContextMenu(url)
                }
            } else {
                ActionButtonSpacer()
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
            }
            .actionButton()
            .actionButtonWidth()
            .allowsHitTesting(!instance.series.isWorking)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: deviceType == .phone ? .center : .leading)
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
                    row("Peers", value: "S: %i  L: %i".placeholders(
                        release.seeders ?? 0,
                        release.leechers ?? 0
                    ))
                }
            }
            .padding(.bottom)
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    var runtime: Int {
        (instance.series.byId(seriesId)?.runtime ?? 0) * release.episodeCount
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
        .padding(.vertical, 4)
    }

    func downloadRelease(force: Bool = false) async {
        guard await instance.series.download(
            guid: release.guid,
            indexerId: release.indexerId,
            seriesId: force ? seriesId : nil,
            seasonId: force ? seasonId : nil,
            episodeId: force && episodeId != nil ? episodeId : nil
        ) else {
            return
        }

        dismiss()

        if let inCalendarSheet {
            inCalendarSheet.pop()
        } else if !dependencies.router.seriesPath.isEmpty {
            dependencies.router.seriesPath.removeLast()
        }

        dependencies.toast.show(.downloadQueued)

        Telemetry.record(release.fullSeason ? .seasonDownloaded : .episodeDownloaded)
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
