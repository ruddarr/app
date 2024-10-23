import SwiftUI

struct Information: View {
    var items: [InformationItem]

    @Environment(\.deviceType) private var deviceType

    var body: some View {
        if deviceType == .phone {
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
                            .buttonStyle(.plain)
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
        guard lhs.label == rhs.label, lhs.value == rhs.value else {
            return false
        }

        switch (lhs.link, rhs.link) {
        case (nil, nil):
            return true
        case let (lhsLink?, rhsLink?):
            return lhsLink.equals(rhsLink)
        default:
            return false
        }
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
