import SwiftUI

extension SeriesDetails {
    var information: some View {
        Section {
            Information(items: informationItems)
        } header: {
            HStack {
                Text("Information")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // TODO: cleanup
//                NavigationLink(
//                    "Files & History",
//                    value: MoviesPath.metadata(movie.id)
//                )
            }
        }
        .font(.callout)
    }

    var informationItems: [InformationItem] {
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
                label: String(localized: "Root Folder"),
                value: series.rootFolderPath ?? "Unknown",
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "New Seasons"),
                value: series.monitorNewItems == .all ? "Monitored" : "Unmonitored",
                link: SeriesPath.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Season Folders"),
                value: series.seasonFolder ? "Yes" : "No",
                link: SeriesPath.edit(series.id)
            ),
        ]

        return items
    }
}
