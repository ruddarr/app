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
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(String(movie.year))
                    Text("•")
                    Text(movie.humanRuntime)
                }.font(.caption)

                HStack(spacing: 8) {
                    Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                    Text(movie.monitored ? "Monitored" : "Unmonitored")
                }.font(.caption)

                Group {
                    if movie.sizeOnDisk != nil && movie.sizeOnDisk! > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text(ByteCountFormatter().string(fromByteCount: Int64(movie.sizeOnDisk!)))
                        }.font(.caption)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text("Missing")
                        }.font(.caption)
                    }
                }

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
