import SwiftUI

struct TMDB {
    static let imageBase = "https://image.tmdb.org/t/p/w500"
    static let backdropBase = "https://image.tmdb.org/t/p/w1280"

    // MARK: - Categories
    enum Category: Hashable, Identifiable {
        var id: String { String(describing: self) }
        case trending
        case popular
        case topRated
        case upcoming // Movies: Upcoming, TV: On The Air
        case genre(Int) // Specific Genre ID
        var label: String {
            switch self {
            case .trending: "Trending"
            case .popular: "Popular"
            case .topRated: "Top Rated"
            case .upcoming: "Upcoming"
            case .genre(let id): TMDB.genreMap[id] ?? "Unknown"
            }
        }
    }

    // MARK: - Movies
    static func fetchMovies(_ category: Category, apiKey: String, page: Int = 1) async throws -> (movies: [Movie], hasMore: Bool) {
        let endpoint: String
        var params: String = ""

        switch category {
        case .trending: endpoint = "trending/movie/week"
        case .popular: endpoint = "movie/popular"
        case .topRated: endpoint = "movie/top_rated"
        case .upcoming: endpoint = "movie/upcoming"
        case .genre(let id):
            endpoint = "discover/movie"
            params = "&with_genres=\(id)&sort_by=popularity.desc"
        }

        guard let url = URL(string: "https://api.themoviedb.org/3/\(endpoint)?language=en-US&api_key=\(apiKey)&page=\(page)\(params)") else {
            throw AppError("Invalid TMDB URL")
        }

        let response: TMDBMovieResponse = try await API.request(url: url)
        let movies = response.results.map { $0.toMovie() }
        let hasMore = response.page < response.total_pages
        return (movies, hasMore)
    }

    // MARK: - Series
    static func fetchSeries(_ category: Category, apiKey: String, page: Int = 1) async throws -> (series: [Series], hasMore: Bool) {
        let endpoint: String
        var params: String = ""

        switch category {
        case .trending: endpoint = "trending/tv/week"
        case .popular: endpoint = "tv/popular"
        case .topRated: endpoint = "tv/top_rated"
        case .upcoming: endpoint = "tv/on_the_air"
        case .genre(let id):
            endpoint = "discover/tv"
            params = "&with_genres=\(id)&sort_by=popularity.desc"
        }

        guard let url = URL(string: "https://api.themoviedb.org/3/\(endpoint)?language=en-US&api_key=\(apiKey)&page=\(page)\(params)") else {
            throw AppError("Invalid TMDB URL")
        }

        let response: TMDBSeriesResponse = try await API.request(url: url)
        let series = response.results.map { $0.toSeries() }
        let hasMore = response.page < response.total_pages
        return (series, hasMore)
    }
    // TMDB genre catalogs (kept separate for Movies vs TV to avoid invalid categories)
    static let movieGenres: [Int: String] = [
        28: "Action",
        12: "Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10_751: "Family",
        14: "Fantasy",
        36: "History",
        27: "Horror",
        10_402: "Music",
        9_648: "Mystery",
        10_749: "Romance",
        878: "Science Fiction",
        10_770: "TV Movie",
        53: "Thriller",
        10_752: "War",
        37: "Western"
    ]

    static let tvGenres: [Int: String] = [
        10_759: "Action & Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10_751: "Family",
        10_762: "Kids",
        9_648: "Mystery",
        10_763: "News",
        10_764: "Reality",
        10_765: "Sci-Fi & Fantasy",
        10_766: "Soap",
        10_767: "Talk",
        10_768: "War & Politics",
        37: "Western"
    ]

    // Unified map for quick lookup (used for labels)
    static let genreMap: [Int: String] = movieGenres.merging(tvGenres) { current, _ in current }

    // Helper to get sorted genres for the UI
    static var sortedMovieGenres: [(id: Int, name: String)] {
        movieGenres.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }

    static var sortedTVGenres: [(id: Int, name: String)] {
        tvGenres.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }
    static func languageName(for code: String?) -> String {
        guard let code = code else { return "Unknown" }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}
// MARK: - TMDB Response Models
struct TMDBMovieResponse: Decodable {
    let results: [TMDBMovie]
    let page: Int
    let total_pages: Int
    let total_results: Int
}

struct TMDBSeriesResponse: Decodable {
    let results: [TMDBSeries]
    let page: Int
    let total_pages: Int
    let total_results: Int
}

struct TMDBMovie: Decodable {
    let id: Int
    let title: String
    let original_title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let vote_average: Float?
    let vote_count: Int?
    let popularity: Float?
    let original_language: String?
    let genre_ids: [Int]?

    func toMovie() -> Movie {
        let year = (release_date?.split(separator: "-").first).flatMap { Int($0) } ?? 0

        var images: [MediaImage] = []
        if let poster = poster_path {
            images.append(MediaImage(coverType: "poster", remoteURL: "\(TMDB.imageBase)\(poster)", url: nil))
        }
        if let backdrop = backdrop_path {
            images.append(MediaImage(coverType: "fanart", remoteURL: "\(TMDB.backdropBase)\(backdrop)", url: nil))
        }

        let genres = (genre_ids ?? []).compactMap { TMDB.genreMap[$0] }
        let language = MediaLanguage(id: 0, name: TMDB.languageName(for: original_language))

        return Movie(
            tmdbId: id,
            imdbId: nil,
            title: title,
            sortTitle: original_title ?? title,
            studio: nil,
            year: year,
            runtime: 0,
            overview: overview,
            certification: nil,
            youTubeTrailerId: nil,
            originalLanguage: language,
            alternateTitles: [],
            genres: genres,
            ratings: Movie.MovieRatings(imdb: nil, tmdb: MovieRating(votes: vote_count ?? 0, value: (vote_average ?? 0)), metacritic: nil, rottenTomatoes: nil),
            popularity: popularity,
            status: .tba,
            isAvailable: false,
            minimumAvailability: .announced,
            monitored: false,
            qualityProfileId: 1,
            sizeOnDisk: nil,
            hasFile: false,
            path: nil,
            relativePath: nil,
            folderName: nil,
            rootFolderPath: nil,
            added: .distantPast,
            inCinemas: nil,
            physicalRelease: nil,
            digitalRelease: nil,
            tags: [],
            images: images,
            movieFile: nil
        )
    }
}

struct TMDBSeries: Decodable {
    let id: Int
    let name: String
    let original_name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let first_air_date: String?
    let vote_average: Float?
    let vote_count: Int?
    let popularity: Float?
    let original_language: String?
    let genre_ids: [Int]?

    func toSeries() -> Series {
        let year = (first_air_date?.split(separator: "-").first).flatMap { Int($0) } ?? 0

        var images: [MediaImage] = []
        if let poster = poster_path {
            images.append(MediaImage(coverType: "poster", remoteURL: "\(TMDB.imageBase)\(poster)", url: nil))
        }
        if let backdrop = backdrop_path {
            images.append(MediaImage(coverType: "fanart", remoteURL: "\(TMDB.backdropBase)\(backdrop)", url: nil))
        }

        let genres = (genre_ids ?? []).compactMap { TMDB.genreMap[$0] }
        let language = MediaLanguage(id: 0, name: TMDB.languageName(for: original_language))

        return Series(
            title: name,
            titleSlug: nil,
            sortTitle: original_name ?? name,
            tvdbId: id,
            tvRageId: nil,
            tvMazeId: nil,
            imdbId: nil,
            tmdbId: id,
            status: .upcoming,
            seriesType: .standard,
            path: nil,
            folder: nil,
            certification: nil,
            year: year,
            runtime: 0,
            airTime: nil,
            ended: false,
            seasonFolder: true,
            useSceneNumbering: false,
            added: .distantPast,
            firstAired: nil,
            lastAired: nil,
            nextAiring: nil,
            previousAiring: nil,
            monitored: false,
            overview: overview,
            network: nil,
            originalLanguage: language,
            alternateTitles: nil,
            seasons: [],
            tags: [],
            genres: genres,
            images: images,
            ratings: SeriesRatings(votes: vote_count ?? 0, value: (vote_average ?? 0)),
            statistics: nil
        )
    }
}
