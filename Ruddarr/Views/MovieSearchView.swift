import SwiftUI

struct MovieSearchView: View {
    let instance: Instance

    @State private var searchQuery = ""
    @State private var presentingSearch = true
    @State private var isAddingMovie: MovieLookup?

    @State var lookup = MovieLookupModel()

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 15) {
                ForEach(lookup.movies ?? []) { movie in
                    Button {
                        isAddingMovie = movie
                    } label: {
                        MovieLookupRow(movie: movie, instance: instance)
                    }
                    .buttonStyle(.plain)
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
            isPresented: $presentingSearch,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .onChange(of: searchQuery) {
            lookup.movies = nil
        }
        .onSubmit(of: .search) {
            Task {
                await lookup.search(instance, query: searchQuery)
            }
        }
        .alert("Something Went Wrong", isPresented: $lookup.hasError, presenting: lookup.error) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            if lookup.isSearching {
                ProgressView {
                    Text("Loading")
                }
            } else if lookup.movies?.count == 0 {
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
        .cornerRadius(8)
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
    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.search)

    return ContentView()
}
