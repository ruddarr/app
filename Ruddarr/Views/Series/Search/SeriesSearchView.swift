import SwiftUI
import Combine

struct SeriesSearchView: View {
    @State var searchQuery = ""

    @State private var presentingSearch = true

    @Environment(SonarrInstance.self) private var instance

    let searchTextPublisher = PassthroughSubject<String, Never>()

    let gridItemLayout = MovieGridItem.gridItemLayout()
    let gridItemSpacing = MovieGridItem.gridItemSpacing()

    var body: some View {
        @Bindable var seriesLookup = instance.lookup

        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: gridItemSpacing) {
                ForEach(seriesLookup.sortedItems) { series in
                    Button {
                        dependencies.router.seriesPath.append(
                            series.exists
                                ? SeriesView.Path.series(series.id)
                                : SeriesView.Path.preview(try? JSONEncoder().encode(series))
                        )
                    } label: {
                        SeriesGridItem(series: series)
                    }
                }
            }
            .padding(.top, 12)
            .viewPadding(.horizontal)
        }
        .navigationTitle("Series Search")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $presentingSearch,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .disabled(instance.isVoid)
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
            searchTextPublisher.throttle(for: .milliseconds(750), scheduler: DispatchQueue.main, latest: true)
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
            let noSearchResults = instance.lookup.items?.count == 0 && !searchQuery.isEmpty

            if instance.lookup.isSearching && noSearchResults {
                Loading()
            } else if noSearchResults {
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
        if searchQuery.isEmpty {
            instance.lookup.reset()
        } else if oldQuery == newQuery {
            performSearch() // always perform initial search
        } else {
            searchTextPublisher.send(searchQuery)
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .series
    dependencies.router.seriesPath.append(SeriesView.Path.search())

    return ContentView()
        .withAppState()
}
