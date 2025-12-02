import SwiftUI

struct MediaGrid<Item: Identifiable, Content: View>: View {
    var items: [Item]
    var style: GridStyle = .posters
    var content: (Item) -> Content

    @Environment(\.deviceType) private var deviceType

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                content(item)
            }
        }
    }

    var columns: [GridItem] {
        switch style {
        case .posters: switch deviceType {
        case .phone: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)]
        case .mac: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]
        default: [GridItem(.adaptive(minimum: 145, maximum: 180), spacing: 20)]
        }
        case .cards: switch deviceType {
        case .phone: [GridItem(.adaptive(minimum: 300, maximum: 800), spacing: 12)]
        case .mac: [GridItem(.adaptive(minimum: 280, maximum: 450), spacing: 20)]
        default: [GridItem(.adaptive(minimum: 300, maximum: 450), spacing: 20)]
        }
        }
    }

    var spacing: CGFloat {
        deviceType == .phone ? 12 : 20
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    NavigationStack {
        ScrollView {
            MediaGrid(items: movies, style: .cards) { movie in
                MovieGridCard(movie: movie)
            }
            .viewPadding(.horizontal)
        }
    }
    .withAppState()
}
