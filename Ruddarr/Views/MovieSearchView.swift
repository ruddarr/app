import SwiftUI

// https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-a-search-bar-to-filter-your-data

struct MovieSearchView: View {
    @State private var searchQuery = ""
    @State private var isAddingMovie = false
    
    @ObservedObject var movies = MovieLookupModel()
    
    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridItemLayout, spacing: 15) {
                    ForEach(movies.movies) { movie in
                        
                        Button(action: {
                            isAddingMovie.toggle()
                        }) {
                            Text(movie.title)
                        }
                        .sheet(isPresented: $isAddingMovie) {
                            NavigationView {
                                VStack {
                                    Text("Add movie")
                                }
                                .navigationTitle("Add movie")
                                .toolbar {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button("Cancel", action: {
                                            isAddingMovie.toggle()
                                        })
                                    }
                                }
                            }
                        }
                        
                    }
                }.padding(.horizontal)
            }
        }
        // TODO: When the view appears we should always focus on `searchable()`
        //       and show the keyboard. Can we use `isPresented`?
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .onChange(of: searchQuery) {
            Task {
                await movies.search(query: searchQuery)
            }
        }
    }
}

#Preview {
    // TODO: show in the context of "MoviesView" so return button is displayed
    MovieSearchView()
        .withSelectedColorScheme()
}
