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

//                NavigationLink(
//                    "Files & History",
//                    value: MoviesView.Path.metadata(movie.id)
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
                link: SeriesView.Path.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Series Type"),
                value: series.seriesType.label,
                link: SeriesView.Path.edit(series.id)
            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: series.rootFolderPath ?? "Unknown",
                link: SeriesView.Path.edit(series.id)
            ),
        ]

        return items
    }
}
