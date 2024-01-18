import SwiftUI

struct MoviesView: View {
    @State var path: NavigationPath = .init()

    @State private var searchQuery = ""
    @State private var searchPresented = false
    @State private var fetchedMovies = false
    @State private var sort: MovieSort = .init()

    @ObservedObject var movies = MovieModel()

    @AppStorage("movieInstance") private var selectedInstanceId: UUID?
    @AppStorage("instances") private var instances: [Instance] = []

    enum Path: Hashable {
        case search
    }

    var body: some View {
        let gridItemLayout = [
            GridItem(.adaptive(minimum: 250), spacing: 15)
        ]

        NavigationStack(path: $path) {
            Group {
                if let radarrInstance {
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 15) {
                            ForEach(displayedMovies) { movie in
                                NavigationLink {
                                    MovieView(movie: movie)
                                        .navigationTitle(movie.title)
                                } label: {
                                    MovieRow(movie: movie)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.top, searchPresented ? 10 : 0)
                        .padding(.horizontal)
                    }
                    .task {
                        guard !fetchedMovies else { return }
                        fetchedMovies = true

                        await movies.fetch(radarrInstance)
                    }
                    .refreshable {
                        await movies.fetch(radarrInstance)
                    }
                    .navigationDestination(for: Path.self) {
                        switch $0 {
                        case .search:
                            MovieSearchView(instance: radarrInstance)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Radarr Instance",
                        systemImage: "tv.slash",
                        description: Text("Connect a Radarr instance under Settings.")
                    )
                }
            }
            .navigationTitle("Movies")
            .toolbar(content: toolbar)
            .searchable(
                text: $searchQuery,
                isPresented: $searchPresented,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .overlay {
                if case .noInternet? = movies.error {
                    NoInternet()
                } else if displayedMovies.isEmpty && !searchQuery.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                }
            }
            .onAppear {
                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if radarrInstance == nil {
                    selectedInstanceId = radarrInstances.first?.id
                }
            }
        }
    }

    @ToolbarContentBuilder
    func toolbar() -> some ToolbarContent {
        if radarrInstances.count > 1 {
            ToolbarItem(placement: .topBarLeading) {
                Menu("Instance", systemImage: "xserve.raid") {
                    ForEach(radarrInstances) { instance in
                        Button {
                            self.selectedInstanceId = instance.id
                            Task {
                                await movies.fetch(instance)
                            }
                        } label: {
                            HStack {
                                Text(instance.label).frame(maxWidth: .infinity, alignment: .leading)
                                if instance.id == selectedInstanceId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu("Sort by", systemImage: "arrow.up.arrow.down") {
                ForEach(MovieSort.Option.allCases) { sortOption in
                    Button {
                        sort.option = sortOption
                    } label: {
                        HStack {
                            Text(sortOption.title).frame(maxWidth: .infinity, alignment: .leading)
                            if sortOption == sort.option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        if radarrInstance != nil {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Path.search) {
                    Image(systemName: "plus.circle")
                }
            }
        }
    }

    var radarrInstances: [Instance] {
        instances.filter { instance in
            instance.type == .radarr
        }
    }

    var radarrInstance: Instance? {
        radarrInstances.first(where: { $0.id == selectedInstanceId })
    }

    var displayedMovies: [Movie] {
        let unsortedMovies: [Movie]

        if searchQuery.isEmpty {
            unsortedMovies = movies.movies
        } else {
            unsortedMovies = movies.movies.filter { movie in
                movie.title.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        return unsortedMovies.sorted(by: sort.option.isOrderedBefore)
    }
}

struct MovieRow: View {
    var movie: Movie

    var body: some View {
        HStack {
            CachedAsyncImage(url: movie.remotePoster)
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(String(movie.year))
                    Text("•")
                    Text(String(movie.studio ?? ""))
                }.font(.caption)

                HStack(spacing: 8) {
                    Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                    Text(movie.monitored ? "Monitored" : "Unmonitored")
                }.font(.caption)

                Group {
                    if movie.sizeOnDisk != nil && movie.sizeOnDisk! > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text(ByteCountFormatter().string(fromByteCount: Int64(movie.sizeOnDisk!)))
                        }.font(.caption)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text("Missing")
                        }.font(.caption)
                    }
                }

                Spacer()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(4)
    }
}

struct MovieSort {
    var isAscending: Bool = true
    var option: Option = .byTitle

    enum Option: CaseIterable, Hashable, Identifiable {
        var id: Self { self }
        case byTitle
        case byYear

        var title: String {
            switch self {
            case .byTitle:
                "Title"
            case .byYear:
                "Year"
            }
        }

        func isOrderedBefore(_ lhs: Movie, _ rhs: Movie) -> Bool {
            switch self {
            case .byTitle:
                lhs.sortTitle < rhs.sortTitle
            case .byYear:
                lhs.year < rhs.year
            }
        }
    }
}

#Preview {
    ContentView(selectedTab: .movies)
        .withSelectedColorScheme()
}
