import SwiftUI

struct MovieDetailsRatings: View {
    var movie: Movie

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                rotten
                imdb
                tmdb
                metacritic
            }

            HStack(spacing: 12) {
                rotten
                imdb
                metacritic
            }

            HStack(spacing: 12) {
                rotten
                imdb
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    var rotten: some View {
        if let rating = movie.ratings?.rottenTomatoes?.value {
            HStack(spacing: 6) {
                Image("rotten").resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 14)

                Text(String(format: "%.0f%%", rating))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var imdb: some View {
        if let rating = movie.ratings?.imdb?.value {
            HStack(spacing: 6) {
                Image("imdb").resizable()
                    .scaledToFit()
                    .frame(height: 12)

                Text(String(format: "%.1f", rating))
                    .font(.callout)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var tmdb: some View {
        if let rating = movie.ratings?.tmdb?.value, rating > 0 {
            HStack(spacing: 6) {
                Image("tmdb").resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 9)

                Text(String(format: "%.0f%%", rating * 10))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var metacritic: some View {
        if let rating = movie.ratings?.metacritic?.value {
            HStack(spacing: 6) {
                Image("metacritic").resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 14)

                Text(String(format: "%.0f", rating))
            }
        }
    }
}
