import SwiftUI

struct BookGridCard: View {
    var book: Book

    @Environment(\.deviceType) private var deviceType

    var body: some View {
        HStack(alignment: .top, spacing: deviceType == .phone ? 10 : 14) {
            poster
                .frame(width: posterWidth, height: posterWidth * book.posterHeightRatio)
                .clipped()

            VStack(alignment: .leading) {
                Text(book.title)
                    .lineLimit(1)
                    .font(.headline)

                byline

                Spacer()

                icons
            }
            .padding(.vertical, deviceType == .phone ? 8 : 10)
            .padding(.trailing, deviceType == .phone ? 10 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            BookContextMenu(book: book)
        } preview: {
            poster.frame(width: 300, height: 300 * book.posterHeightRatio)
        }
    }

    var byline: some View {
        HStack(spacing: 6) {
            if let author = book.authorLabel {
                Text(author)
            } else {
                Text(book.yearLabel)
            }
        }
        .lineLimit(1)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    var poster: some View {
        CachedAsyncImage(.album, book.remotePoster, placeholder: book.title)
            .scaledToFill()
    }

    var posterWidth: CGFloat {
        deviceType == .phone ? 80 : 90
    }

    var icons: some View {
        HStack {
            let iconScale: Image.Scale = deviceType == .phone ? .small : .medium

            Image(systemName: "bookmark")
                .symbolVariant(book.monitored ? .fill : .none)
                .imageScale(iconScale)

            Group {
                if book.hasFiles {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if book.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .imageScale(iconScale)
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "books")

    NavigationStack {
        ScrollView {
            MediaGrid(items: books, style: .cards) { book in
                BookGridCard(book: book)
            }
            .scenePadding(.horizontal)
        }
        .withAppState()
    }
}
