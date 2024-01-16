import SwiftUI

struct MovieView: View {
    var movie: Movie
    
    var body: some View {
        Text(movie.title)
    }
}

#Preview {
    MovieView(movie: Movie(id: 1, title: "Test", year: 2023, images: []))
}
