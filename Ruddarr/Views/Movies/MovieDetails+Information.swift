import SwiftUI

extension MovieDetails {
    var information: some View {
        Section {
            Information(items: informationItems)
                .font(.subheadline)
        } header: {
            HStack {
                Text("Information")
                    .font(.title2.bold())

                Spacer()

                NavigationLink(
                    "Files & History",
                    value: MoviesPath.metadata(movie.id)
                )
                .font(.callout)
            }
        }
    }

    var informationItems: [InformationItem] {
        var items = [
            InformationItem(
                label: String(localized: "Quality Profile"),
                value: qualityProfile,
                link: MoviesPath.edit(movie.id)
            ),
            InformationItem(
                label: String(localized: "Minimum Availability"),
                value: movie.minimumAvailability.label,
                link: MoviesPath.edit(movie.id)
            ),
            movie.tags.isEmpty ? nil : InformationItem(
                label: String(localized: "Tags"),
                value: formatTags(movie.tags, tags: instance.tags),
                link: MoviesPath.edit(movie.id)
            ),
            InformationItem(
                label: String(localized: "Root Folder"),
                value: movie.rootFolderPath ?? "Unknown",
                link: MoviesPath.edit(movie.id)
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

        return items.compactMap { $0 }
    }
}
