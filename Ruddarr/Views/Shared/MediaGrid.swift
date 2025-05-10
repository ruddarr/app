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
        #if os(macOS)
            return 20
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return 12
            }

            return 20
        #endif
    }
}
