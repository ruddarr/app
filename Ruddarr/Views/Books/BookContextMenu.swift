import SwiftUI

struct BookContextMenu: View {
    var book: Book

    @Environment(ChaptarrInstance.self) private var instance

    var body: some View {
        Group {
            BookLinks(book: book)

            if book.exists {
                Divider()

                Button("Automatic Search", systemImage: "magnifyingglass") {
                    Task { await dispatchSearch() }
                }
            }
        }.tint(.primary)
    }

    func dispatchSearch() async {
        guard await instance.books.command(.bookSearch([book.id])) else {
            return
        }

        dependencies.toast.show(.bookSearchQueued)
    }
}
