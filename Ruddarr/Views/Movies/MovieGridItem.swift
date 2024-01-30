import SwiftUI

// TODO: clock
// Status: Released, In Cinemas, Announced

struct MovieGridItem: View {
    var movie: Movie

    var body: some View {

        HStack {
            CachedAsyncImage(url: movie.remotePoster)
                .aspectRatio(
                    CGSize(width: 50, height: 75),
                    contentMode: .fill
                )
                .mask(
                    LinearGradient(
                        gradient: Gradient(colors: [.black, .black, .black, .black, .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.secondarySystemBackground)
        .cornerRadius(8)
        .overlay(alignment: .bottom) {
            HStack {
                Image(systemName: movie.hasFile ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(.white)
            }
            .font(.body)
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
        }
    }
}

//struct MovieRow: View {
//    var movie: Movie
//
//    var body: some View {
//        HStack {
//            CachedAsyncImage(url: movie.remotePoster)
//                .scaledToFit()
//                .frame(width: 100)
//                .clipped()
//
//            VStack(alignment: .leading, spacing: 4) {
//                Text(movie.title)
//                    .font(.title3)
//                    .fontWeight(.bold)
//
//                HStack(spacing: 4) {
//                    Text(String(movie.year))
//                    Text("•")
//                    Text(movie.humanRuntime)
//                }.font(.body)
//
//                HStack(spacing: 8) {
//                    Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
//                    Text(movie.monitored ? "Monitored" : "Unmonitored")
//                }.font(.body)
//
//                Group {
//                    if movie.sizeOnDisk != nil && movie.sizeOnDisk! > 0 {
//                        HStack(spacing: 8) {
//                            Image(systemName: "doc")
//                            Text(ByteCountFormatter().string(fromByteCount: Int64(movie.sizeOnDisk!)))
//                        }.font(.body)
//                    } else {
//                        HStack(spacing: 8) {
//                            Image(systemName: "doc")
//                            Text("Missing")
//                        }.font(.body)
//                    }
//                }
//
//                Spacer()
//            }
//            .padding(.top, 4)
//
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .background(.secondarySystemBackground)
//        .cornerRadius(8)
//    }
//}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
    ]

    return ScrollView {
        LazyVGrid(columns: gridItemLayout, spacing: 12) {
            ForEach(movies) { movie in
                MovieGridItem(movie: movie)
            }
        }
        .padding(.top, 0)
        .scenePadding(.horizontal)
    }
    .withAppState()
}
