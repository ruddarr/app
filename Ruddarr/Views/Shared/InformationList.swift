import SwiftUI

struct Information: View {
    var items: [InformationItem]

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            informationList
        } else {
            informationGrid
        }
    }

    var informationList: some View {
        VStack(spacing: 12) {
            ForEach(items, id: \.self) { item in
                if item != items.first {
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
            ForEach(items, id: \.self) { item in
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
}

struct InformationItem: Hashable {
    var label: String
    var value: String
    var link: (any Hashable)?

    static func == (lhs: InformationItem, rhs: InformationItem) -> Bool {
        lhs.label == rhs.label && lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(value)

        if let link = link {
            hasher.combine(link)
        } else {
            hasher.combine(0)
        }
    }
}
