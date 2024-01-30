import SwiftUI

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
                Group {
                    if movie.hasFile {
                        Image(systemName: "checkmark.circle.fill")
                    } else if movie.isWaiting {
                        Image(systemName: "clock")
                    } else if movie.monitored {
                        Image(systemName: "xmark.circle")
                    }
                }.foregroundStyle(.white)

                Spacer()

                Image(systemName: "bookmark")
                    .symbolVariant(movie.monitored ? .fill : .none)
                    .foregroundStyle(.white)
            }
            .font(.body)
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
        .sorted { $0.year > $1.year }

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
