import SwiftUI

struct MediaGrid<Item: Identifiable, Content: View, Header: View>: View {
    var items: [Item]
    var style: GridStyle = .posters
    var content: (Item) -> Content
    var header: Header?

    @Environment(\.deviceType) private var deviceType

    init(
        items: [Item],
        style: GridStyle = .posters,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.items = items
        self.style = style
        self.content = content
        self.header = header()
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            if let header {
                Section {
                    ForEach(items) { item in
                        content(item).geometryGroup()
                    }
                } header: {
                    header
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(items) { item in
                    content(item).geometryGroup()
                }
            }
        }
    }

    var columns: [GridItem] {
        switch style {
        case .posters: switch deviceType {
        case .phone: [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)]
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

extension MediaGrid where Header == Never {
    init(
        items: [Item],
        style: GridStyle = .posters,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.style = style
        self.content = content
        self.header = nil
    }
}

@MainActor @Observable
final class PosterMetrics {
    static let shared = PosterMetrics()

    private init() {}

    var gridWidth: CGFloat = 200
}

extension View {
    func tracksGridPosterWidth() -> some View {
        #if os(macOS)
            onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                if width > 0, abs(PosterMetrics.shared.gridWidth - width) > 0.5 {
                    PosterMetrics.shared.gridWidth = width
                }
            }
        #else
            self
        #endif
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    NavigationStack {
        ScrollView {
            MediaGrid(items: movies, style: .cards) { movie in
                MovieGridCard(movie: movie)
            }
            .scenePadding(.horizontal)
        }
    }
    .withAppState()
}
