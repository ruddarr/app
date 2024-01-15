import SwiftUI

struct MoviesView: View {
    @State private var searchQuery = ""
    @State private var fetchedMovies = false
    @State private var sort: MovieSort = .init()
    
    @ObservedObject var movies = MovieModel()
    
    @AppStorage("movieInstance") private var instanceId: UUID?
    @AppStorage("instances") private var instances: [Instance] = []

    init() {
        if instanceId == nil {
            instanceId = radarrInstances.first?.id
        }
    }
    
    var body: some View {
        let gridItemLayout = [
            GridItem(.adaptive(minimum: 250))
        ]
        
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridItemLayout, spacing: 15) {
                    ForEach(displayedMovies) { movie in
                        NavigationLink {
                            MovieView(movie: movie)
                                .navigationTitle(movie.title)
                        } label: {
                            MovieRow(movie: movie)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Movies")
            .toolbar(content: toolbar)
            .task {
                guard !fetchedMovies else { return }
                fetchedMovies = true
                
                await movies.fetch(radarrInstance)
            }
            .refreshable {
                await movies.fetch(radarrInstance)
            }
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always))
        .overlay {
            if displayedMovies.isEmpty && !searchQuery.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }
    
    @ToolbarContentBuilder
    func toolbar() -> some ToolbarContent {
        if (radarrInstances.count > 1) {
            ToolbarItem(placement: .topBarLeading) {
                Menu("Instance", systemImage: "server.rack") {
                    ForEach(radarrInstances) { instance in
                        Button {
                            self.instanceId = instance.id
                            Task {
                                await movies.fetch(radarrInstance)
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
        
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                MovieSearchView(instance: radarrInstance)
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }
    
    var radarrInstances: [Instance] {
        return instances.filter { instance in
            return instance.type == .radarr
        }
    }
    
    var radarrInstance: Instance {
        return radarrInstances.first(where: { $0.id == instanceId })!
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
                lhs.title < rhs.title
            case .byYear:
                lhs.year < rhs.year
            }
        }
        
    }
}

struct MovieRow: View {
    var movie: Movie
    
    var body: some View {
        HStack {
            AsyncImage(
                url: URL(string: movie.remotePoster ?? ""),
                content: { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 80, maxHeight: .infinity)
                },
                placeholder: {
                    ProgressView()
                }
            )
            VStack(alignment: .leading) {
                Text(movie.title)
                    .font(.footnote)
                    .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.leading)
                Text(String(movie.year))
                    .font(.caption)
                Spacer()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(4)
    }
}

#Preview {
    ContentView(selectedTab: .movies)
        .withSelectedColorScheme()
}
