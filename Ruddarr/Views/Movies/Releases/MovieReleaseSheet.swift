import SwiftUI

struct MovieReleaseSheet: View {
    @State var release: MovieRelease

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                if !release.rejections.isEmpty {
                    rejections
                        .padding(.bottom)
                }

                actions
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom)

                details
                    .padding(.bottom)
            }
            .padding(.top)
            .scenePadding(.horizontal)
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { instance.movies.error != nil }, set: { _ in }),
            presenting: instance.movies.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
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

            Text(release.title)
                .font(.title2)
                .fontWeight(.bold)
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Text("•")
                Text(release.sizeLabel)
                Text("•")
                Text(release.ageLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    var rejections: some View {
        GroupBox(label:
            Text("Release Rejected")
                .padding(.bottom, 4)
        ) {
            VStack(alignment: .leading) {
                ForEach(release.rejections, id: \.self) { rejection in
                    Text(rejection)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            if let url = release.infoUrl {
                Link(destination: URL(string: url)!, label: {
                    ButtonLabel(text: "Open Link", icon: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Button {
                Task {
                    await instance.movies.download(
                        guid: release.guid,
                        indexerId: release.indexerId
                    )
                }
            } label: {
                ButtonLabel(
                    text: "Download",
                    icon: "arrow.down.circle",
                    isLoading: instance.movies.isWorking
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.movies.isWorking)
        }
    }

    var details: some View {
        Section(
            header: Text("Information")
                .font(.title2)
                .fontWeight(.bold)
        ) {
            VStack(spacing: 12) {
                if let language = release.languageLabel {
                    row("Language", value: language)
                    Divider()
                }

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
}

#Preview {
    let releases: [MovieRelease] = PreviewData.load(name: "releases")
    let release = releases[50]

    return MovieReleaseSheet(release: release)
        .withAppState()
}
