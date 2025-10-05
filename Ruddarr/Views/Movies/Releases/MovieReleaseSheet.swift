import SwiftUI
import TelemetryDeck

struct MovieReleaseSheet: View {
    var release: MovieRelease
    var movie: Movie

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @State private var showGrabConfirmation: Bool = false

    var body: some View {
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
                .viewPadding(.horizontal)
                .offset(y: -45)
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }.tint(.primary)
                }
            }
            .alert(
                isPresented: instance.movies.errorBinding,
                error: instance.movies.error
            ) { _ in
                Button("OK") { instance.movies.error = nil }
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
                Text("The release for this movie could not be determined and it may not import automatically. Do you want to grab \"\(release.title)\"?")
            }.tint(nil)
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
        .background(.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .buttonStyle(.glass)
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
                let label: String = deviceType == .phone
                    ? String(localized: "Download", comment: "Short version of Download Release")
                    : String(localized: "Download Release")

                ButtonLabel(
                    text: label,
                    icon: "arrow.down.circle",
                    isLoading: instance.movies.isWorking
                )
                .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.glass)
            .allowsHitTesting(!instance.movies.isWorking)

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

                row("Bitrate", value: release.bitrateLabel(movie.runtime) ?? "--")
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
            .padding(.bottom)
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    func flags() -> [String] {
        var flags: [String] = []

        if let indexerFlags = release.indexerFlags, !indexerFlags.isEmpty {
            flags.append(contentsOf: release.cleanIndexerFlags)
        }

        if release.isProper {
            flags.append(String(localized: "Proper", comment: "The PROPER flag"))
        }

        if release.isRepack {
            flags.append(String(localized: "Repack", comment: "The REPACK flag"))
        }

        return flags
    }

    func tags() -> [String] {
        var tags: [String] = []

        if release.customFormatScore != 0 {
            tags.append(release.scoreLabel)
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
        .padding(.vertical, 4)
    }

    func downloadRelease(force: Bool = false) async {
        guard await instance.movies.download(
            guid: release.guid,
            indexerId: release.indexerId,
            movieId: force ? movie.id : nil
        ) else {
            return
        }

        dismiss()

        if !dependencies.router.moviesPath.isEmpty {
            dependencies.router.moviesPath.removeLast()
        }

        dependencies.toast.show(.downloadQueued)

        TelemetryDeck.signal("releaseDownloaded", parameters: ["type": "movie"])
        maybeAskForReview()
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let releases: [MovieRelease] = PreviewData.load(name: "movie-releases")
    let release = releases[10]

    MovieReleaseSheet(release: release, movie: movies[1])
        .withAppState()
}
