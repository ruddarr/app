import SwiftUI

struct MovieRatings: View {
    var movie: Movie

    @Environment(\.deviceType) private var deviceType

    var body: some View {
        let badges = badges

        ViewThatFits(in: .horizontal) {
            row(badges.prefix(5))
            row(badges.prefix(4))
            row(badges.prefix(3))
            row(badges.prefix(2))
            row(badges.prefix(1))
        }
        .font(deviceType == .phone ? .subheadline : .callout)
        .foregroundStyle(.secondary)
    }

    private func row(_ badges: ArraySlice<Badge>) -> some View {
        let badges = Array(badges)

        return HStack(spacing: deviceType == .phone ? 10 : 12) {
            if badges.count > 0 { view(for: badges[0]) }
            if badges.count > 1 { view(for: badges[1]) }
            if badges.count > 2 { view(for: badges[2]) }
            if badges.count > 3 { view(for: badges[3]) }
            if badges.count > 4 { view(for: badges[4]) }
        }
    }

    private var badges: [Badge] {
        var badges: [Badge] = []

        if let rating = movie.ratings?.rottenTomatoes?.value {
            badges.append(.rottenTomatoes(rating))
        }

        if let rating = movie.ratings?.imdb?.value {
            badges.append(.imdb(rating))
        }

        if let rating = movie.ratings?.tmdb?.value, rating > 0 {
            badges.append(.tmdb(rating))
        }

        if let rating = movie.ratings?.metacritic?.value {
            badges.append(.metacritic(rating))
        }

        if let rating = movie.ratings?.trakt?.value, rating > 0 {
            badges.append(.trakt(rating))
        }

        return badges
    }

    @ViewBuilder
    private func view(for badge: Badge) -> some View {
        switch badge {
        case .rottenTomatoes(let rating):
            HStack(spacing: 4) {
                Image(rating > 60 ? "rt-fresh" : "rt-rotten")
                    .resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 14)
                    .offset(y: -0.5)

                Text(rating.formatted(.percentageRating))
                    .lineLimit(1)
            }
        case .imdb(let rating):
            HStack(spacing: 5) {
                Image("imdb").resizable()
                    .scaledToFit()
                    .frame(height: 12)
                    .offset(y: -0.5)

                Text(rating.formatted(
                    .number.precision(.fractionLength(1)).grouping(.never)
                        .locale(Locale(identifier: "en_US_POSIX"))
                ))
                    .font(.callout)
                    .lineLimit(1)
            }
        case .tmdb(let rating):
            HStack(spacing: 5) {
                Image("tmdb").resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 11)
                    .offset(y: -0.5)

                Text((rating * 10).formatted(.percentageRating))
                    .lineLimit(1)
            }
        case .metacritic(let rating):
            HStack(spacing: 5) {
                Image("metacritic").resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 14)
                    .offset(y: -0.5)

                Text(rating.formatted(.decimal(0)))
                    .lineLimit(1)
            }
        case .trakt(let rating):
            HStack(spacing: 5) {
                Image("trakt").resizable()
                    .scaledToFit()
                    .font(.callout)
                    .frame(height: 13)
                    .offset(y: -0.5)

                Text((rating * 10).formatted(.percentageRating))
                    .lineLimit(1)
            }
        }
    }

    private enum Badge: Identifiable {
        case rottenTomatoes(Float)
        case imdb(Float)
        case tmdb(Float)
        case metacritic(Float)
        case trakt(Float)

        var id: String {
            switch self {
            case .rottenTomatoes: "rottenTomatoes"
            case .imdb: "imdb"
            case .tmdb: "tmdb"
            case .metacritic: "metacritic"
            case .trakt: "trakt"
            }
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first { $0.id == 1 } ?? movies[0]

    return NavigationStack {
        ScrollView {
            MovieDetails(movie: movie)
                .padding()
        }
    }
    .withRadarrInstance(movies: movies)
    .withAppState()
    .macPreviewFrame()
}
