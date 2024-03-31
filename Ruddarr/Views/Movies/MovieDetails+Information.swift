import SwiftUI

extension MovieDetails {
    var information: some View {
        Section {
            if UIDevice.current.userInterfaceIdiom == .phone {
                VStack(spacing: 12) {
                    ForEach(informationItems, id: \.self) { item in
                        if item != informationItems.first {
                            Divider()
                        }

                        LabeledContent {
                            Text(item.value).foregroundStyle(.primary)
                        } label: {
                            Text(item.label).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

                LazyVGrid(columns: columns, alignment: .leading) {
                    ForEach(informationItems, id: \.self) { item in
                        VStack(alignment: .leading) {
                            Text(item.label).foregroundStyle(.secondary)
                            Text(item.value).lineLimit(1)
                        }
                        .font(.subheadline)
                        .padding(.bottom)
                    }
                }
            }
        } header: {
            HStack {
                Text("Information")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink(
                    "Files & History",
                    value: MoviesView.Path.metadata(movie.id)
                )
            }
        }
        .font(.callout)
    }

    struct InformationItem: Hashable {
        var label: String
        var value: String
    }

    var informationItems: [InformationItem] {
        var items = [
            InformationItem(
                label: String(localized: "Quality Profile"),
                value: qualityProfile
            ),
            InformationItem(
                label: String(localized: "Minimum Availability"),
                value: movie.minimumAvailability.label
            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: movie.rootFolderPath ?? "Unknown"
            ),
        ]

        if let inCinemas = movie.inCinemas {
            items.append(InformationItem(
                label: String(localized: "In Cinemas"),
                value: inCinemas.formatted(.dateTime.day().month().year()))
            )
        }

        if let digitalRelease = movie.digitalRelease {
            items.append(InformationItem(
                label: String(localized: "Digital Release"),
                value: digitalRelease.formatted(.dateTime.day().month().year()))
            )
        }

        if let physicalRelease = movie.physicalRelease {
            items.append(InformationItem(
                label: String(localized: "Physical Release"),
                value: physicalRelease.formatted(.dateTime.day().month().year()))
            )
        }

        return items
    }
}
