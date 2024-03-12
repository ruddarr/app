import SwiftUI

struct MovieReleaseSheet: View {
    @State var release: MovieRelease

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                    .padding(.bottom)
            }
            .padding(.top)
            .viewPadding(.horizontal)
        }
        .alert(
            "Something Went Wrong",
            isPresented: instance.movies.errorBinding,
            presenting: instance.movies.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            if error.localizedDescription == "cancelled" {
                let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MovieReleaseSheet") // swiftlint:disable:this redundant_discardable_let
            }

            Text(error.localizedDescription)
        }
    }

    var header: some View {
        VStack(alignment: .leading) {
            if !release.indexerFlags.isEmpty {
                HStack {
                    ForEach(release.cleanIndexerFlags, id: \.self) { flag in
                        Text(flag).textCase(.uppercase)
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(settings.theme.tint)
            }

            Text(release.cleanTitle)
                .font(.title2)
                .fontWeight(.bold)
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
            if let url = release.infoUrl {
                Link(destination: URL(string: url)!, label: {
                    ButtonLabel(text: String(localized: "Open Link"), icon: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Button {
                Task { await downloadRelease() }
            } label: {
                ButtonLabel(
                    text: String(localized: "Download"),
                    icon: "arrow.down.circle",
                    isLoading: instance.movies.isWorking
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.movies.isWorking)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var details: some View {
        Section(
            header: Text("Information")
                .font(.title2)
                .fontWeight(.bold)
        ) {
            VStack(spacing: 12) {
                if let language = release.languageLabel {
                    row(String(localized: "Language"), value: language)
                    Divider()
                }

                row(String(localized: "Indexer"), value: release.indexerLabel)

                if release.isTorrent {
                    Divider()
                    row(String(localized: "Peers"), value: String(
                        format: "S: %i  L: %i",
                        release.seeders ?? 0,
                        release.leechers ?? 0
                    ))
                }
            }
            .font(.callout)
        }
    }

    func row(_ label: String, value: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.primary)
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
    }

    @MainActor
    func downloadRelease() async {
        guard await instance.movies.download(
            guid: release.guid,
            indexerId: release.indexerId
        ) else {
            return
        }

        dismiss()
        dependencies.router.moviesPath.removeLast()
        dependencies.toast.show(.downloadQueued)
    }
}

#Preview {
    let releases: [MovieRelease] = PreviewData.load(name: "releases")
    let release = releases[50]

    return MovieReleaseSheet(release: release)
        .withAppState()
}
