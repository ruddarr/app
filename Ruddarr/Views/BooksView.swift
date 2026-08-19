import SwiftUI

enum BooksPath: Hashable {
    case search(String = "")
    case preview(Data?)
    case book(Book.ID)
    case metadata(Book.ID)
}

struct BooksView: View {
    @AppStorage("bookSort", store: dependencies.store) var sort: BookSort = .init()

    @Environment(AppSettings.self) var settings
    @Environment(ChaptarrInstance.self) var instance

    @Environment(\.deviceType) private var deviceType

    @State private var scrollView: ScrollViewProxy?

    @State private var searchQuery = ""
    @State private var searchPresented = false
    @State private var searchRequest: SearchRequest?

    @State private var error: API.Error?
    @State private var alertPresented = false

    @State private var lastFetch: Date = .distantPast

    var body: some View {
        // swiftlint:disable:next closure_body_length
        NavigationStack(path: dependencies.$router.booksPath) {
            Group {
                if instance.isVoid {
                    NoInstance(type: "Chaptarr")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            mediaGrid

                            loadMoreSentinel

                            if instance.books.cachedItems.count > 42 {
                                mediaCount
                            }

                            if presentSearchSuggestion {
                                BookSearchSuggestion(
                                    query: $searchQuery,
                                    sort: $sort,
                                    hiddenByFormat: hiddenByFormat
                                )
                            }
                        }
                        .onAppear {
                            scrollView = proxy
                        }
                    }
                    .task {
                        guard !instance.isVoid else { return }
                        await fetchBooksThrottled()
                        await fetchInstanceMetadata()
                    }
                    .refreshable {
                        await Task { await fetchBooksWithAlert() }.value
                    }
                    .onBecomeActive(perform: becameActive)
                }
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BooksPath.self) {
                BooksDestination(path: $0)
            }
            .onAppear {
                maybeSwitchToInstance()

                if instance.isVoid, let first = settings.chaptarrInstances.first {
                    settings.chaptarrInstanceId = first.id
                    changeInstance()
                }
            }
            .toolbar {
                toolbarViewOptions
                toolbarSearchButton

                if settings.chaptarrInstances.count > 1 {
                    if deviceType == .phone { toolbarInstancePicker }
                    if deviceType == .pad { bottomBarInstancePicker }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .searchable(
                text: $searchQuery,
                isPresented: $searchPresented,
                placement: .drawerOrToolbar
            )
            .autocorrectionDisabled(true)
            .onChange(of: settings.chaptarrInstanceId, changeInstance)
            .onChange(of: sort.option, updateSortDirection)
            .onChange(of: sort, handleFilterChange)
            .onChange(of: searchQuery, handleQueryChange)
            .onChange(of: instance.books.items, updateDisplayedBooks)
            .task(id: searchRequest) {
                guard let searchRequest, await searchRequest.waitForDebounce() else { return }
                updateDisplayedBooks()
            }
            .sensoryAlert(isPresented: $alertPresented, error: error) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }.tint(nil)
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if isLoadingBooks {
                    Loading()
                } else if hasNoSearchResults {
                    NoBookSearchResults(
                        query: $searchQuery,
                        sort: $sort,
                        hiddenByFormat: hiddenByFormat
                    )
                } else if hasNoMatchingResults {
                    noMatchingResults
                } else if initialLoadingFailed {
                    contentUnavailable
                }
            }
        }
    }

    @ViewBuilder
    var loadMoreSentinel: some View {
        if searchQuery.trimmed().isEmpty, instance.books.hasMoreItems {
            LazyVStack {
                ProgressView()
                    .tint(.secondary)
                    .padding(.vertical, 24)
                    .onAppear {
                        Task { await instance.books.loadMore(sort) }
                    }
            }
        }
    }

    var mediaGrid: some View {
        MediaGrid(
            items: instance.books.cachedItems,
            style: settings.grid
        ) { book in
            NavigationLink(value: BooksPath.book(book.id)) {
                switch settings.grid {
                case .posters: BookGridPoster(book: book)
                case .cards: BookGridCard(book: book)
                }
            }
            .buttonStyle(.plain)
            .id(book.id)
        }
        .animation(.snappy, value: instance.books.cachedItems.map(\.id))
        .viewBottomPadding()
        .scenePadding(.horizontal)
        #if os(iOS)
            .padding(.top, searchPresented ? 7 : 0)
        #elseif os(macOS)
            .padding(.vertical)
        #endif
    }

    var mediaCount: some View {
        HStack(spacing: 6) {
            Text("\(instance.books.cachedItems.count) Book")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom)
    }

    var notConnectedToInternet: Bool {
        if !instance.books.cachedItems.isEmpty { return false }
        if case .notConnectedToInternet = error { return true }
        return false
    }

    var hasNoSearchResults: Bool {
        !searchQuery.isEmpty && !instance.isVoid && instance.books.cachedItems.isEmpty
    }

    var hasNoMatchingResults: Bool {
        instance.books.cachedItems.isEmpty && instance.books.itemsCount > 0
    }

    var presentSearchSuggestion: Bool {
        searchPresented && !instance.books.cachedItems.isEmpty
    }

    var isLoadingBooks: Bool {
        (instance.books.isWorking || instance.books.isFiltering) &&
        instance.books.cachedItems.isEmpty
    }

    var initialLoadingFailed: Bool {
        guard instance.books.itemsCount == 0 else { return false }
        return instance.books.error != nil
    }

    var hiddenByFormat: BookSort.BookMediaType? {
        guard !instance.books.items.isEmpty else { return nil }
        guard !instance.books.items.contains(where: sort.mediaType.matches) else { return nil }

        return BookSort.BookMediaType.allCases.first { type in
            instance.books.items.contains(where: type.matches)
        }
    }

    var noMatchingResults: some View {
        ContentUnavailableView {
            Label("No Books Match", systemImage: "slash.circle")
        } description: {
            Text("No books match the selected format and filter.")
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
    }

    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("Connection Failure", systemImage: "exclamationmark.triangle")
        } description: {
            Text(instance.books.error?.recoverySuggestionFallback ?? "")
        } actions: {
            Button("Retry") {
                Task { await fetchBooksWithAlert(ignoreOffline: true) }
            }
        }
    }

    func updateSortDirection() {
        sort.isAscending = switch sort.option {
        case .byTitle: true
        default: false
        }
    }

    func updateDisplayedBooks() {
        instance.books.updateCachedItems(sort, searchQuery)
    }

    func fetchInstanceMetadata() async {
        let lastMetadataFetch = "instanceMetadataFetch:\(instance.id)"
        let cacheInSeconds: Double = instance.isSlow ? 300 : 30

        guard Occurrence.since(lastMetadataFetch) > cacheInSeconds else { return }

        if let model = await instance.fetchMetadata() {
            settings.saveInstanceMetadata(model)
            Occurrence.occurred(lastMetadataFetch)
        }
    }

    func fetchBooksThrottled() async {
        guard Date.now.timeIntervalSince(lastFetch) >= 15 else { return }
        _ = await instance.books.fetch(sort)
        updateDisplayedBooks()
        lastFetch = .now
    }

    func fetchBooksWithAlert(ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        _ = await instance.books.fetch(sort)
        updateDisplayedBooks()

        if let apiError = instance.books.error {
            error = apiError

            if case .notConnectedToInternet = apiError, ignoreOffline {
                return
            }

            alertPresented = true
        }
    }

    func handleFilterChange() {
        scrollToTop()
        lastFetch = .distantPast

        Task { await fetchBooksWithAlert() }
    }

    func handleQueryChange() {
        scrollToTop()
        searchRequest = SearchRequest(query: searchQuery, isDebounced: true)
    }

    func becameActive() {
        guard dependencies.router.booksPath.isEmpty else { return }

        Task { @MainActor in
            _ = await instance.books.fetch(sort)
            updateDisplayedBooks()
            lastFetch = .now
        }
    }

    func scrollToTop() {
        withAnimation(.smooth) {
            scrollView?.scrollTo(
                instance.books.cachedItems.first?.id
            )
        }
    }

    func maybeSwitchToInstance() {
        guard let idOrName = dependencies.router.switchToChaptarrInstance else { return }
        guard let switchTo = settings.instanceBy(idOrName) else { return }

        if switchTo.id != instance.id {
            dependencies.router.switchToChaptarrInstance = nil
            settings.chaptarrInstanceId = switchTo.id
            changeInstance()
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .books

    InstancesStore.shared.setInstances([.chaptarrDummy])
    AppSettings.shared.chaptarrInstanceId = Instance.chaptarrDummy.id

    return ContentView()
        .withAppState()
}
