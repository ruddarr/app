import SwiftUI

extension MovieDetails {
    var information: some View {
        Section(
            header: Text("Information")
                .font(.title2)
                .fontWeight(.bold)
        ) {
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
        }
        .font(.callout)
    }

    struct InformationItem: Hashable {
        var label: String
        var value: String
    }

    var informationItems: [InformationItem] {
        var items = [
            InformationItem(label: "Quality Profile", value: qualityProfile),
            InformationItem(label: "Minimum Availability", value: movie.minimumAvailability.label),
            InformationItem(label: "Root Folder", value: movie.rootFolderPath ?? "Unknown"),
        ]

        if movie.isDownloaded {
            items.append(InformationItem(label: "Size", value: movie.sizeLabel))
        }

        if let inCinemas = movie.inCinemas {
            items.append(InformationItem(label: "In Cinemas", value: inCinemas.formatted(.dateTime.day().month().year())))
        }

        if let digitalRelease = movie.digitalRelease {
            items.append(InformationItem(label: "Digital Release", value: digitalRelease.formatted(.dateTime.day().month().year())))
        }

        if let physicalRelease = movie.physicalRelease {
            items.append(InformationItem(label: "Physical Release", value: physicalRelease.formatted(.dateTime.day().month().year())))
        }

        return items
    }
}
