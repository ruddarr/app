import SwiftUI

struct MovieView: View {
    var movie: Movie
    
    var body: some View {
        Text(movie.title)
    }
}

//#Preview {
//    MovieView(movie: )
//}
