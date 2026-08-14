import SwiftUI

struct NoBookSearchResults: View {
    @Binding var query: String
    @Binding var sort: BookSort

    var hiddenByFormat: BookSort.BookMediaType?

    var body: some View {
        let description = String(localized: "Check the spelling or try [adding the book](%@).")
            .placeholders("#view")

        ContentUnavailableView {
            Label("No Results for \"\(query)\"", systemImage: "magnifyingglass")
        } description: {
            Text(description.toMarkdown())
        } actions: {
            if sort.filter != .all || hiddenByFormat != nil {
                Button("Clear Filter") {
                    sort.filter = .all

                    if let hiddenByFormat {
                        sort.mediaType = hiddenByFormat
                    }
                }
            }
        }
        .environment(\.openURL, .init { _ in
            dependencies.router.booksPath.append(BooksPath.search(query))
            query = ""

            return .handled
        })
    }
}

struct BookSearchSuggestion: View {
    @Binding var query: String
    @Binding var sort: BookSort

    var hiddenByFormat: BookSort.BookMediaType?

    var body: some View {
        let description = String(localized: "Looking to [add a new book](%@)?")
            .placeholders("#view")

        Text(description.toMarkdown())
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .environment(\.openURL, .init { _ in
                dependencies.router.booksPath.append(BooksPath.search(query))
                query = ""

                return .handled
            })

        if sort.filter != .all || hiddenByFormat != nil {
            Button("Clear Filters") {
                sort.filter = .all

                if let hiddenByFormat {
                    sort.mediaType = hiddenByFormat
                }
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
    }
}
