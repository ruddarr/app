import SwiftUI
import Combine

struct ArtistSearchView: View {
    @State var searchQuery: String
    @State private var searchPresented: Bool = true

    @Environment(LidarrInstance.self) private var instance

    let searchTextPublisher = PassthroughSubject<String, Never>()

    var body: some View {
        @Bindable var discovery = Discovery.shared
        @Bindable var artistsLookup = instance.lookup

        ScrollView {
            if artistsLookup.sortedItems.isEmpty && searchQuery.isEmpty {
                MediaGrid(items: discovery.artists) { item in
                    DiscoveryGridPoster(item: item)
                } header: {
                    Text("Popular This Week")
                        .padding(.top, 12)
                }
                .viewBottomPadding()
                .scenePadding(.horizontal)
                .opacity(discovery.series.isEmpty ? 0 : 1)
                .animation(.easeIn, value: discovery.series)
            } else {
                MediaGrid(items: artistsLookup.sortedItems) { artist in
                    ArtistSearchItem(artist: artist)
                        .environment(instance)
                }
                .padding(.top, 12)
                .scenePadding(.horizontal)
                .viewBottomPadding()
            }
        }
        .navigationTitle("Search")
        .safeNavigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
        .searchable(
            text: $searchQuery,
            isPresented: $searchPresented,
            placement: .drawerOrToolbar(.always)
        )
        .disabled(instance.isVoid)
        .autocorrectionDisabled(true)
        .searchScopes($artistsLookup.sort) {
            ForEach(SeriesLookup.SortOption.allCases) { option in
                Text(option.label)
            }
        }
        .task {
            await discovery.fetch(.series)
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
        }.tint(nil)
        .overlay {
            if instance.lookup.isSearching && instance.lookup.isEmpty() {
                Loading()
            } else if instance.lookup.noResults(searchQuery) {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }

    func performSearch() {
        Task { @MainActor in
            await instance.lookup.search(query: searchQuery)
        }
    }

    func handleSearchQueryChange(oldQuery: String, newQuery: String) {
        if let mbId = extractMbId(newQuery) {
            searchQuery = "mb:\(mbId)"
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

struct ArtistSearchItem: View {
    var artist: Artist

    @Environment(LidarrInstance.self) private var instance

    var body: some View {
        NavigationLink(value: destination) {
            ArtistGridPoster(artist: artist, model: model)
        }
        .buttonStyle(.plain)
    }

    var destination: ArtistsPath {
        if artist.exists {
            return .artist(artist.id)
        }

        do {
            let data = try JSONEncoder().encode(artist)
            return .preview(data)
        } catch {
            leaveBreadcrumb(.fatal, category: "artists.search", message: "Failed to encode", data: ["error": error])
        }

        return .search()
    }

    var model: Artist? {
        guard let id = artist.guid else { return nil }
        return instance.artists.byId(id)
    }
}

#Preview {
    dependencies.router.selectedTab = .artists
    dependencies.router.artistsPath.append(ArtistsPath.search())

    return ContentView()
        .withAppState()
}
