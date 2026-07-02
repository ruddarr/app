import SwiftUI
import Sentry

@MainActor
@Observable
class Discovery {
    static let shared = Discovery()
    static let url: String = "https://api.ruddarr.com"

    private var movieItems: DiscoveryItems?
    private var seriesItems: DiscoveryItems?

    enum MediaType: String {
        case movies
        case series
    }

    var movies: [DiscoveryItem] {
        guard let items = movieItems?.popular else { return [] }
        guard Platform.deviceType == .phone else { return items }
        return Array(items.prefix(24))
    }

    var series: [DiscoveryItem] {
        guard let items = seriesItems?.popular else { return [] }
        guard Platform.deviceType == .phone else { return items }
        return Array(items.prefix(24))
    }

    func fetch(_ type: MediaType) async {
        switch type {
        case .movies:
            if isCurrentWindow(movieItems?.timestamp) { return }
            movieItems = await load(.movies)
        case .series:
            if isCurrentWindow(seriesItems?.timestamp) { return }
            seriesItems = await load(.series)
        }
    }

    private func isCurrentWindow(_ timestamp: String?) -> Bool {
        guard let timestamp else { return false }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: timestamp) else { return false }

        return calendar.isDateInToday(date)
    }

    private func load(_ type: MediaType) async -> DiscoveryItems? {
        // return PreviewData.loadObject(name: "popular-\(type.rawValue)")

        guard let baseURL = URL(string: Discovery.url) else { return nil }

        do {
            let url = baseURL
                .appending(path: "/discover/\(type.rawValue)")
                .appending(queryItems: [
                    URLQueryItem(name: "language", value: Locale.current.identifier(.bcp47))
                ])

            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let (json, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

            guard statusCode < 400 else {
                leaveBreadcrumb(.error, category: "discovery", message: "Bad status code", data: ["status": statusCode])

                return nil
            }

            return try JSONDecoder().decode(DiscoveryItems.self, from: json)
        } catch {
            leaveBreadcrumb(.error, category: "discovery", message: "Request failed", data: ["error": error])
        }

        return nil
    }
}

struct DiscoveryItems: Codable, Equatable {
    let timestamp: String
    let popular: [DiscoveryItem]
}

struct DiscoveryItem: Identifiable, Codable, Equatable {
    let id: Int
    let type: ItemType
    let title: String
    let overview: String
    let release_date: String
    let popularity: Double
    let vote_average: Double
    let vote_count: Int
    let score: Double
    let poster_path: String

    enum ItemType: String, Codable {
        case movie
        case series
    }

    @MainActor
    func libraryMovie(in instance: RadarrInstance) -> Movie? {
        guard type == .movie else { return nil }
        return instance.movies.cachedItems.first { $0.tmdbId == id }
    }

    @MainActor
    func librarySeries(in instance: SonarrInstance) -> Series? {
        guard type == .series else { return nil }
        return instance.series.cachedItems.first { $0.tmdbId == id }
    }
}
