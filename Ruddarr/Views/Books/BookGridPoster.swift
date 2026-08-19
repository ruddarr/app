import SwiftUI

struct BookGridPoster: View {
    var book: Book

    var type: ImageType = .album

    var aspect: CGSize {
        type == .poster ? CGSize(width: 150, height: 225) : book.posterAspect
    }

    var heightRatio: CGFloat {
        type == .poster ? 1.5 : book.posterHeightRatio
    }

    var body: some View {
        Color.card
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { poster }
            .overlay(alignment: .bottom) {
                if book.exists {
                    BookPosterOverlay(book: book)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contextMenu {
                BookContextMenu(book: book)
            } preview: {
                poster.frame(width: 300, height: 300 * heightRatio)
            }
            .tracksGridPosterWidth()
    }

    var poster: some View {
        CachedAsyncImage(type, book.remotePoster, placeholder: book.title)
            .scaledToFill()
    }
}

struct BookPosterOverlay: View {
    var book: Book

    var body: some View {
        MediaGridPosterOverlay {
            Group {
                if book.hasFiles {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if book.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .foregroundStyle(.white)
            .imageScale(.gridItem)

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(book.monitored ? .fill : .none)
                .foregroundStyle(.white)
                .imageScale(.gridItem)
        }
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "books")

    ScrollView {
        MediaGrid(items: books) { book in
            BookGridPoster(book: book)
        }
        .scenePadding(.horizontal)
    }
    .withAppState()
}
