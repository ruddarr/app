import Foundation

struct InstanceStats: Equatable, Codable {
    let movies: Int
    let series: Int
    let episodes: Int
    let books: Int
    let size: Int

    init(movies: [Movie]) {
        self.movies = movies.count
        self.series = 0
        self.episodes = 0
        self.books = 0
        self.size = movies.reduce(0) { $0 + ($1.sizeOnDisk ?? 0) }
    }

    init(series: [Series]) {
        self.movies = 0
        self.series = series.count
        self.episodes = series.reduce(0) { $0 + $1.episodeFileCount }
        self.books = 0
        self.size = series.reduce(0) { $0 + ($1.statistics?.sizeOnDisk ?? 0) }
    }

    init(books: [Book]) {
        self.movies = 0
        self.series = 0
        self.episodes = 0
        self.books = books.count
        self.size = books.reduce(0) { $0 + ($1.sizeOnDisk ?? 0) }
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        movies = try values.decodeIfPresent(Int.self, forKey: .movies) ?? 0
        series = try values.decodeIfPresent(Int.self, forKey: .series) ?? 0
        episodes = try values.decodeIfPresent(Int.self, forKey: .episodes) ?? 0
        books = try values.decodeIfPresent(Int.self, forKey: .books) ?? 0
        size = try values.decodeIfPresent(Int.self, forKey: .size) ?? 0
    }

    @concurrent static func make(movies: [Movie]) async -> Self {
        Self(movies: movies)
    }

    @concurrent static func make(series: [Series]) async -> Self {
        Self(series: series)
    }

    @concurrent static func make(books: [Book]) async -> Self {
        Self(books: books)
    }
}
