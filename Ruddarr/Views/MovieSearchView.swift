import SwiftUI

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
                            MovieLookupRow(movie: movie)
                        }
                        .sheet(isPresented: $isAddingMovie) {
                            NavigationView {
                                VStack {
                                    Text("Add movie")
                                }
                                .navigationTitle(movie.title)
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

struct MovieLookupRow: View {
    var movie: MovieLookup
    
    var body: some View {
        HStack {
//            AsyncImage(
//                url: URL(string: movie.images[0].remoteURL),
//                content: { image in
//                    image.resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(maxWidth: 80, maxHeight: .infinity)
//                },
//                placeholder: {
//                    ProgressView()
//                }
//            )
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
    MovieSearchView()
        .withSelectedColorScheme()
}
