import SwiftUI

extension MovieDetails {
    var information: some View {
        Section {
            Information(items: informationItems)
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

    var informationItems: [InformationItem] {
        var items = [
            InformationItem(
                label: String(localized: "Quality Profile"),
                value: qualityProfile,
                link: MoviesView.Path.edit(movie.id)
            ),
            InformationItem(
                label: String(localized: "Minimum Availability"),
                value: movie.minimumAvailability.label,
                link: MoviesView.Path.edit(movie.id)
            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: movie.rootFolderPath ?? "Unknown",
                link: MoviesView.Path.edit(movie.id)
            ),
        ]

        if let inCinemas = movie.inCinemas {
            items.append(InformationItem(
                label: String(localized: "In Cinemas"),
                value: inCinemas.formatted(date: .abbreviated, time: .omitted)
            ))
        }

        if let digitalRelease = movie.digitalRelease {
            items.append(InformationItem(
                label: String(localized: "Digital Release"),
                value: digitalRelease.formatted(date: .abbreviated, time: .omitted)
            ))
        }

        if let physicalRelease = movie.physicalRelease {
            items.append(InformationItem(
                label: String(localized: "Physical Release"),
                value: physicalRelease.formatted(date: .abbreviated, time: .omitted)
            ))
        }

        return items
    }
}
