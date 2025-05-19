import SwiftUI
import Combine

struct SeriesSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = true

    @Environment(SonarrInstance.self) private var instance

    let searchTextPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        @Bindable var seriesLookup = instance.lookup

        ScrollView {
            MediaGrid(items: instance.lookup.sortedItems) { series in
                SeriesSearchItem(series: series)
                    .environment(instance)
            }
            .padding(.top, 12)
            .viewPadding(.horizontal)
            .viewBottomPadding()
        }
        .navigationTitle("Search")
        .safeNavigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar
        )
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .searchScopes($seriesLookup.sort) {
            ForEach(SeriesLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .onSubmit(of: .search) {
            searchTextPublisher.send(searchQuery)
        }
        .onChange(of: searchQuery, initial: true, handleSearchQueryChange)
        .onReceive(
            searchTextPublisher.debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
        ) { _ in
            performSearch()
        }
        .alert(
            isPresented: instance.lookup.errorBinding,
            error: instance.lookup.error
        ) { _ in
            Button("OK") { instance.lookup.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .overlay {
            if instance.lookup.isSearching && instance.lookup.isEmpty() {
                Loading()
            } else if instance.lookup.noResults(searchQuery) {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    func performSearch() {
        Task {
            await instance.lookup.search(query: searchQuery)
        }
    }

    func handleSearchQueryChange(oldQuery: String, newQuery: String) {
        if let imdb = extractImdbId(newQuery) {
            searchQuery = "imdb:\(imdb)"
            return
        }

        if searchQuery.isEmpty {
            if oldQuery.count > 3 { return }
            instance.lookup.reset()
        } else if oldQuery == newQuery {
            performSearch() // always perform initial search
        } else {
            searchTextPublisher.send(searchQuery)
        }
    }
}

struct SeriesSearchItem: View {
    var series: Series

    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        NavigationLink(value: destination) {
            SeriesGridPoster(series: series, model: model)
        }
        .buttonStyle(.plain)
    }

    var destination: SeriesPath {
        if series.exists {
            return .series(series.id)
        }

        do {
            let data = try JSONEncoder().encode(series)
            return .preview(data)
        } catch {
            leaveBreadcrumb(.fatal, category: "series.search", message: "Failed to encode", data: ["error": error])
        }

        return .search()
    }

    var model: Series? {
        guard let id = series.guid else { return nil }
        return instance.series.byId(id)
    }
}

#Preview {
    dependencies.router.selectedTab = .series
    dependencies.router.seriesPath.append(SeriesPath.search())

    return ContentView()
        .withAppState()
}
