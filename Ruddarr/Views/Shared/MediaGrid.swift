import SwiftUI

struct MediaGrid<Item: Identifiable, Content: View>: View {
    var items: [Item]
    var style: GridStyle = .posters
    var content: (Item) -> Content

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        LazyVGrid(columns: gridItemLayout, spacing: gridItemSpacing) {
            ForEach(items) { item in
                content(item)
            }
        }
    }

    var gridItemLayout: [GridItem] {
        switch settings.grid {
        case .posters: MovieGridPoster.gridItemLayout()
        case .cards: MovieGridCard.gridItemLayout()
        }
    }

    var gridItemSpacing: CGFloat {
        deviceType == .phone ? 12 : 20
    }
}
