import SwiftUI

struct MediaGrid<Item: Identifiable, Content: View>: View {
    var items: [Item]
    var style: GridStyle = .posters
    var content: (Item) -> Content

    @EnvironmentObject var settings: AppSettings

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
        switch settings.grid {
        case .posters: MovieGridPoster.gridItemSpacing()
        case .cards: MovieGridCard.gridItemSpacing()
        }
    }
}
