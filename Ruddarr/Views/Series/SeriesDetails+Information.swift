import SwiftUI

extension SeriesDetails {
    var information: some View {
        Section {
            if UIDevice.current.userInterfaceIdiom == .phone {
                informationList
            } else {
                informationGrid
            }
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

    var informationList: some View {
        VStack(spacing: 12) {
            ForEach(informationItems, id: \.self) { item in
                if item != informationItems.first {
                    Divider()
                }

                let label = Text(item.value).lineLimit(1).truncationMode(.head)

                LabeledContent {
                    Group {
                        if let link = item.link {
                            NavigationLink(value: link, label: { label })
                        } else {
                            label
                        }
                    }.foregroundStyle(.primary)
                } label: {
                    Text(item.label).foregroundStyle(.secondary)
                }
            }
        }
    }

    var informationGrid: some View {
        let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

        return LazyVGrid(columns: columns, alignment: .leading) {
            ForEach(informationItems, id: \.self) { item in
                VStack(alignment: .leading) {
                    Text(item.label).foregroundStyle(.secondary)
                    let label = Text(item.value).lineLimit(1).truncationMode(.head)

                    if let link = item.link {
                        NavigationLink(value: link, label: { label })
                            .foregroundStyle(.primary)
                    } else {
                        label
                    }
                }
                .font(.subheadline)
                .padding(.bottom)
            }
        }
    }

    struct InformationItem: Hashable {
        var label: String
        var value: String
        var link: SeriesView.Path?
    }

    var informationItems: [InformationItem] {
        var items = [
            InformationItem(
                label: String(localized: "Quality Profile"),
                value: qualityProfile,
                link: SeriesView.Path.edit(series.id)
            ),
            // Series Type
//            InformationItem(
//                label: String(localized: "Minimum Availability"),
//                value: series.minimumAvailability.label,
//                link: MoviesView.Path.edit(series.id)
//            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: series.rootFolderPath ?? "Unknown",
                link: SeriesView.Path.edit(series.id)
            ),
        ]

//        if let inCinemas = series.inCinemas {
//            items.append(InformationItem(
//                label: String(localized: "In Cinemas"),
//                value: inCinemas.formatted(.dateTime.day().month().year()))
//            )
//        }
//
//        if let digitalRelease = movie.digitalRelease {
//            items.append(InformationItem(
//                label: String(localized: "Digital Release"),
//                value: digitalRelease.formatted(.dateTime.day().month().year()))
//            )
//        }
//
//        if let physicalRelease = movie.physicalRelease {
//            items.append(InformationItem(
//                label: String(localized: "Physical Release"),
//                value: physicalRelease.formatted(.dateTime.day().month().year()))
//            )
//        }

        return items
    }
}
