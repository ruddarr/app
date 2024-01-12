import SwiftUI

struct MovieView: View {
    var movie: Movie
    
    var body: some View {
        Text(movie.title)
    }
}

// TODO: The preview should load a ramdom a fixed movie, so the preview isn't failing

//#Preview {
//    MovieView(movie: )
//}
