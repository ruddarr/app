import SwiftUI

struct MovieRatings: View {
    var movie: Movie
    
    let spacing: CGFloat = 12
    let contentSpacing: CGFloat = 4

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                rotten
                imdb
                tmdb
                metacritic
            }

            HStack(spacing: spacing) {
                rotten
                imdb
                metacritic
            }

            HStack(spacing: spacing) {
                rotten
                imdb
            }
        }
    }

    @ViewBuilder
    var rotten: some View {
        if let rating = movie.ratings?.rottenTomatoes?.value {
            HStack(spacing: contentSpacing) {
                Image(rating > 60 ? "rt-fresh" : "rt-rotten").resizable()
                    .scaledToFit()
                    .frame(height: rating > 60 ? 14 : 18)

                Text(String(format: "%.0f%%", rating))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var imdb: some View {
        if let rating = movie.ratings?.imdb?.value {
            HStack(spacing: contentSpacing) {
                Image("imdb").resizable()
                    .scaledToFit()
                    .frame(height: 13)

                Text(String(format: "%.1f", rating))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var tmdb: some View {
        if let rating = movie.ratings?.tmdb?.value, rating > 0 {
            HStack(spacing: contentSpacing) {
                Image("tmdb").resizable()
                    .scaledToFit()
                    .frame(height: 12)

                Text(String(format: "%.0f%%", rating * 10))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    var metacritic: some View {
        if let rating = movie.ratings?.metacritic?.value {
            HStack(spacing: contentSpacing) {
                Image("metacritic").resizable()
                    .scaledToFit()
                    .frame(height: 14)

                Text(String(format: "%.0f", rating))
            }
        }
    }
}
