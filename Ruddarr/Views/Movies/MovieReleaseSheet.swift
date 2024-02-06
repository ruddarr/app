import SwiftUI

struct MovieReleaseSheet: View {
    @State var release: MovieRelease

    var body: some View {
        VStack(alignment: .leading) {
            Text(release.title)
                .font(.title2)
                .fontWeight(.bold)
                .kerning(-0.5)
                .padding(.bottom)

            Section(
                header: Text("Information")
                    .font(.title2)
                    .fontWeight(.bold)
            ) {
                VStack(spacing: 12) {
                    row("Quality", value: release.quality.quality.name)
                    Divider()
                    row("Size", value: release.sizeLabel)
                    Divider()
                    row("Age", value: release.ageLabel)
                    Divider()
                    row("Type", value: release.typeLabel)
                    Divider()
                    row("Indexer", value: release.indexerLabel)

                    // Rejection reasons
                    // Flags!!!
                    // Download (two actions?)

                    // Seeders / Leechers
                    // Language(s)
                    // Link to URL
                }
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .padding(.top)
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
    let release = releases.first(where: { $0.mappedMovieId == 145 }) ?? releases[0]

    return MovieReleaseSheet(release: release)
        .withAppState()
}
