import SwiftUI

extension SeriesDetails {
    var information: some View {
        Section {
            Information(items: informationItems)
                .font(.subheadline)
        } header: {
            Text("Information").font(.title2.bold()).padding(.top)
        }
    }

    var informationItems: [InformationItem] {
        let tagLabels = series.tags.map { tagId in
            instance.tags.first { $0.id == tagId }?.label ?? "tag:\(tagId)"
        }.joined(separator: ", ")

        let items = [
            InformationItem(
                label: String(localized: "Quality Profile"),
                value: qualityProfile,
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Series Type"),
                value: series.seriesType.label,
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Tags"),
                value: series.tags.isEmpty ? String(localized: "None") : tagLabels,
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: series.rootFolderPath ?? "Unknown",
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "New Seasons"),
                value: series.monitorNewItems == .all
                    ? String(localized: "Monitored")
                    : String(localized: "Unmonitored"),
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Season Folders"),
                value: series.seasonFolder
                    ? String(localized: "Yes")
                    : String(localized: "No"),
                link: SeriesPath.edit(series.id)
            ),
        ]

        return items
    }
}
