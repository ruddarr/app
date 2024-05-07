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
        var items = [
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
        ]

        // TODO: dates
        // "firstAired": "2005-11-06T00:00:00Z",
        // "lastAired": "2014-06-23T00:00:00Z",

        // monitorNewItems
        // season folders?

        return items
    }
}
