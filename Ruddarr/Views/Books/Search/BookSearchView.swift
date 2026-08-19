import SwiftUI

struct BookSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = true
    @State private var searchRequest: SearchRequest?

    @Environment(ChaptarrInstance.self) private var instance

    var body: some View {
        ScrollView {
            MediaGrid(items: instance.lookup.items ?? []) { book in
                NavigationLink(value: book.exists
                    ? BooksPath.book(book.id)
                    : BooksPath.preview(try? JSONEncoder().encode(book))
                ) {
                    BookGridPoster(book: book, type: .poster)
                }.buttonStyle(.plain)
            }
            .padding(.top, 12)
            .scenePadding(.horizontal)
            .viewBottomPadding()
        }
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar(.always),
            prompt: Text(
                "e.g. \("The Name of the Wind, gr:2502879")",
                comment: "Placeholder in the search field on the Add Movie/Series screens (translate only \"e.g.\", short form of \"for example\")"
            )
        )
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: searchQuery, initial: true, handleSearchQueryChange)
        .task(id: searchRequest) {
            guard let searchRequest, await searchRequest.waitForDebounce() else { return }

            await instance.lookup.search(query: searchRequest.query)
        }
        .sensoryAlert(
            isPresented: instance.lookup.errorBinding,
            error: instance.lookup.error
        ) { _ in
            Button("OK") { instance.lookup.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .overlay {
            if instance.lookup.isSearching && instance.lookup.isEmpty() {
                Loading()
            } else if instance.lookup.noResults(searchQuery) {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    func performSearch(debounced: Bool = false) {
        searchRequest = SearchRequest(query: searchQuery, isDebounced: debounced)
    }

    func handleSearchQueryChange(oldQuery: String, newQuery: String) {
        if searchQuery.isEmpty {
            if oldQuery.count > 3 { return }
            instance.lookup.reset()
        } else if oldQuery == newQuery {
            performSearch() // always perform initial search
        } else {
            performSearch(debounced: true)
        }
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "books")

    dependencies.router.selectedTab = .books
    dependencies.router.booksPath.append(BooksPath.search())

    return ContentView()
        .withChaptarrInstance(books: books)
        .withAppState()
}
