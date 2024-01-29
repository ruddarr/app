import SwiftUI

struct MovieRow: View {
    var movie: Movie

    var body: some View {
        HStack {
            CachedAsyncImage(url: movie.remotePoster)
                .scaledToFit()
                .frame(width: 100)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: 4) {
                    Text(String(movie.year))
                    Text("•")
                    Text(movie.humanRuntime)
                }.font(.body)

                HStack(spacing: 8) {
                    Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                    Text(movie.monitored ? "Monitored" : "Unmonitored")
                }.font(.body)

                Group {
                    if movie.sizeOnDisk != nil && movie.sizeOnDisk! > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text(ByteCountFormatter().string(fromByteCount: Int64(movie.sizeOnDisk!)))
                        }.font(.body)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text("Missing")
                        }.font(.body)
                    }
                }

                Spacer()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.secondarySystemBackground)
        .cornerRadius(8)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]

    return ScrollView {
        LazyVGrid(columns: gridItemLayout, spacing: 15) {
            ForEach(movies) { movie in
                NavigationLink(value: "") {
                    MovieRow(movie: movie)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 0)
        .scenePadding(.horizontal)
    }
    .withAppState()
}
