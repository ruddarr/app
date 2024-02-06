import SwiftUI

struct MovieReleaseSheet: View {
    @State var release: MovieRelease

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(release.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .kerning(-0.5)
                    .padding(.bottom)

                HStack(spacing: 24) {
                    if let url = release.infoUrl {
                        Link(destination: URL(string: url)!, label: {
                            Label("Visit Link", systemImage: "arrow.up.right.square")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(settings.theme.tint)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                        })
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .frame(maxWidth: .infinity)
                    }

                    Button {
                        // TODO: needs action
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(settings.theme.tint)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom)

                VStack(spacing: 12) {
                    row("Quality", value: release.quality.quality.name)
                    // TODO: resolution as well
                    Divider()
                    row("Size", value: release.sizeLabel)
                    Divider()
                    row("Age", value: release.ageLabel)
                    Divider()
                    row("Type", value: release.typeLabel)
                    // TODO: Seeders / Leechers

                    if let language = release.languageLabel {
                        Divider()
                        row("Language", value: language)
                    }

                    Divider()
                    row("Indexer", value: release.indexerLabel)

                    if let flags = release.flagsLabel {
                        Divider()
                        row("Flags", value: flags)
                    }

                    // Rejection reasons
                    // Download (two actions?)

                    // TODO: Link to URL
                }
                .font(.callout)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .padding(.top)
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
    let release = releases[1]

    return MovieReleaseSheet(release: release)
        .withAppState()
}
