import SwiftUI

struct MoviesView: View {
    @State private var searchQuery = ""
    @State private var searchPresented = false
    @State private var fetchedMovies = false
    @State private var sort: MovieSort = .init()
    
    @ObservedObject var movies = MovieModel()
    
    @AppStorage("movieInstance") private var instanceId: UUID?
    @AppStorage("instances") private var instances: [Instance] = [.sample] //TODO: remove the hardcoded sample instance from here once we have a way to inject it when needed

    enum Path: Hashable {
        case search
    }
    @State var path: NavigationPath = .init()
    
    var body: some View {
        let gridItemLayout = [
            GridItem(.adaptive(minimum: 250), spacing: 15)
        ]
        
        NavigationStack(path: $path) {
            Group {
                if let radarrInstance {
                    ScrollView {
                        Text(String(describing: path))
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
                        "No Radarr instance",
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
                if displayedMovies.isEmpty && !searchQuery.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                }
            }
            //TODO: maybe we only want this to happen onFirst appear, but I think it shouldn't matter. Personally, I'd try to model thing such that this kind of state synchronization isn't needed (e.g. allow instanceId to be nil, assume first instance is selected in that case)
            // this used to be done in a custom init but didn't seem to work for me (maybe AppStorage wasn't ready by then?)
            .onAppear {
                if instanceId == nil {
                    instanceId = radarrInstances.first?.id
                }
            }
        }
        
    }
    
    @ToolbarContentBuilder
    func toolbar() -> some ToolbarContent {
        if (radarrInstances.count > 1) {
            ToolbarItem(placement: .topBarLeading) {
                Menu("Instance", systemImage: "xserve.raid") {
                    ForEach(radarrInstances) { instance in
                        Button {
                            self.instanceId = instance.id
                            Task {
                                await movies.fetch(instance)
                            }
                        } label: {
                            HStack {
                                Text(instance.label).frame(maxWidth: .infinity, alignment: .leading)
                                if instance.id == instanceId {
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
        
        if let radarrInstance {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Path.search)  {
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
        radarrInstances.first(where: { $0.id == instanceId })
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
            AsyncImage(
                url: URL(string: movie.remotePoster ?? ""),
                content: { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                },
                placeholder: {
                    ProgressView()
                }
            )
            .frame(width: 85, height: 125)

            VStack(alignment: .leading) {
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
