import SwiftUI

@MainActor
@Observable
class Discovery {
    static let shared = Discovery()
    static let url: String = "http://192.168.40.73:8787"
    static let railItemLimit = 6

    private var moviePopularItems: DiscoveryItems?
    private var movieUpcomingItems: DiscoveryItems?
    private var seriesPopularItems: DiscoveryItems?
    private var seriesUpcomingItems: DiscoveryItems?

    enum MediaType: String {
        case movies
        case series
    }

    var movies: [DiscoveryItem] {
        items(from: moviePopularItems)
    }

    var upcomingMovies: [DiscoveryItem] {
        items(from: movieUpcomingItems)
    }

    var series: [DiscoveryItem] {
        items(from: seriesPopularItems)
    }

    var upcomingSeries: [DiscoveryItem] {
        items(from: seriesUpcomingItems)
    }

    private func items(from response: DiscoveryItems?) -> [DiscoveryItem] {
        guard let items = response?.popular else { return [] }
        guard Platform.deviceType == .phone else { return items }
        return Array(items.prefix(24))
    }

    func fetch(_ type: MediaType) async {
        switch type {
        case .movies:
            if !isCurrentWindow(moviePopularItems?.timestamp) {
                moviePopularItems = await load(.movies, .popular)
            }

            if !isCurrentWindow(movieUpcomingItems?.timestamp) {
                movieUpcomingItems = await load(.movies, .upcoming)
            }
        case .series:
            if !isCurrentWindow(seriesPopularItems?.timestamp) {
                seriesPopularItems = await load(.series, .popular)
            }

            if !isCurrentWindow(seriesUpcomingItems?.timestamp) {
                seriesUpcomingItems = await load(.series, .upcoming)
            }
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

    private func load(_ type: MediaType, _ section: DiscoverySection) async -> DiscoveryItems? {
        // return PreviewData.loadObject(name: "popular-\(type.rawValue)")

        guard let baseURL = URL(string: Discovery.url) else { return nil }

        do {
            let url = baseURL
                .appending(path: "/\(section.endpoint)/\(type.rawValue)")
                .appending(queryItems: queryItems(for: section))

            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let (json, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

            guard statusCode < 400 else {
                leaveBreadcrumb(.error, category: "discovery", message: "Bad status code", data: [
                    "status": statusCode,
                    "endpoint": section.endpoint,
                    "type": type.rawValue,
                ])

                return nil
            }

            return try JSONDecoder().decode(DiscoveryItems.self, from: json)
        } catch {
            leaveBreadcrumb(.error, category: "discovery", message: "Request failed", data: [
                "error": error,
                "endpoint": section.endpoint,
                "type": type.rawValue,
            ])
        }

        return nil
    }

    private func queryItems(for section: DiscoverySection) -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        let language = Locale.current.identifier(.bcp47)
        if !language.isEmpty {
            items.append(.init(name: "language", value: language))
        }

        if section == .upcoming {
            let region = Locale.current.region?.identifier ?? "US"
            items.append(.init(name: "region", value: region))
        }

        return items
    }
}

struct DiscoveryItems: Codable, Equatable {
    let timestamp: String
    let popular: [DiscoveryItem]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case popular
        case upcoming
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        popular = try container.decodeIfPresent([DiscoveryItem].self, forKey: .popular)
            ?? container.decodeIfPresent([DiscoveryItem].self, forKey: .upcoming)
            ?? []
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(popular, forKey: .popular)
    }
}

enum DiscoverySection: String, Hashable {
    case popular
    case upcoming

    var endpoint: String {
        switch self {
        case .popular: "discover"
        case .upcoming: "upcoming"
        }
    }
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
    let poster_path: String?

    enum ItemType: String, Codable {
        case movie
        case series
    }
}
