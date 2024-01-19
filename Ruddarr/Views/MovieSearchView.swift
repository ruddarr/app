import SwiftUI

struct MovieSearchView: View {
    let instance: Instance

    @State private var searchQuery = ""
    @State private var isSearching = true
    @State private var displayingResults = false
    @State private var isAddingMovie: MovieLookup?

    @State var lookup = MovieLookupModel()

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 15) {
                ForEach(lookup.movies) { movie in
                    Button {
                        isAddingMovie = movie
                    } label: {
                        MovieLookupRow(movie: movie, instance: instance)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .sheet(item: $isAddingMovie) { movie in
                    MovieLookupSheet(movie: movie)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)
        }
        .navigationTitle("Add Movie")
        .searchable(
            text: $searchQuery,
            isPresented: $isSearching,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .onChange(of: searchQuery) {
            displayingResults = false
        }
        .onSubmit(of: .search) {
            Task {
                displayingResults = false
                await lookup.search(instance, query: searchQuery)
                displayingResults = true
            }
        }
        .overlay {
            if case .noInternet? = lookup.error {
                NoInternet()
            } else if displayingResults && lookup.movies.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }
}

struct MovieLookupRow: View {
    var movie: MovieLookup
    var instance: Instance

    var body: some View {
        HStack {
            CachedAsyncImage(url: movie.remotePoster)
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipped()

            VStack(alignment: .leading) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.leading)
                Text(String(movie.year))
                    .font(.caption)
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

struct MovieLookupSheet: View {
    var movie: MovieLookup

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Add movie")
            }
            .navigationTitle(movie.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: {
                        dismiss()
                    })
                }
            }
        }
    }
}

#Preview {
    // This preview only works when at least one instance was added in settings

    MoviesView(path: .init([MoviesView.Path.search]))
}
