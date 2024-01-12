import SwiftUI

// TODO: switch between instances (top left)
// TODO: open "detail view" for each movie (and edit for each movie)
// TODO: cache the results and display them when the app was closed? (write json file to disk or use SwiftData)

//    URLCache.shared.memoryCapacity = 50_000_000 // ~50 MB memory space
//    URLCache.shared.diskCapacity = 1_000_000_000 // ~1GB disk cache space

struct MoviesView: View {
    @State private var searchQuery = ""
    @State private var fetchedMovies = false
    @State private var sort: MovieSort = .init()
    
    @ObservedObject var movies = MovieModel()
    
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
                }.padding(.horizontal)
            }
            .navigationTitle("Movies")
            .toolbar(content: toolbar)
            .task {
                guard !fetchedMovies else { return }
                fetchedMovies = true
                
                await movies.fetch()
            }
            .refreshable {
                await movies.fetch()
            }
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always))
    }
    
    @ToolbarContentBuilder
    func toolbar() -> some ToolbarContent {
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
        ToolbarItem(placement: .topBarLeading) {
            Image(systemName: "server.rack")
        }
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
                url: URL(string: movie.images[0].remoteURL),
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
