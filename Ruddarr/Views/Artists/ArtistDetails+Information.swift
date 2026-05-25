import SwiftUI

extension ArtistDetails {
    var information: some View {
        Section {
            Information(items: informationItems)
                .font(.subheadline)
        } header: {
            Text("Information").font(.title2.bold()).padding(.top)
        }
    }

    var informationItems: [InformationItem] {
        let items = [
            InformationItem(
                label: String(localized: "Quality Profile"),
                value: qualityProfile,
                link: ArtistsPath.edit(artist.id)
            ),
            InformationItem(
                label: String(localized: "Metadata Profile"),
                value: metadataProfile,
                link: ArtistsPath.edit(artist.id)
            ),
            artist.tags.isEmpty ? nil : InformationItem(
                label: String(localized: "Tags"),
                value: formatTags(artist.tags, tags: instance.tags),
                link: ArtistsPath.edit(artist.id)
            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: artist.rootFolderPath ?? "Unknown",
                link: ArtistsPath.edit(artist.id)
            ),
            InformationItem(
                label: String(localized: "New Releases"),
                value: artist.monitorNewItems == .all
                    ? String(localized: "Monitored")
                    : String(localized: "Unmonitored"),
                link: ArtistsPath.edit(artist.id)
            ),
        ]

        return items.compactMap { $0 }
    }
}
