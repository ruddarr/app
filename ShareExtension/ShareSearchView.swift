import SwiftUI

// MARK: - Lightweight API Models

struct ShareMediaImage: Codable {
    let coverType: String
    let remoteURL: String?

    enum CodingKeys: String, CodingKey {
        case coverType
        case remoteURL = "remoteUrl"
    }
}

struct ShareMovieResult: Identifiable, Codable {
    var id: Int { guid ?? (tmdbId + 100_000) }

    let guid: Int?
    let tmdbId: Int
    let title: String
    let year: Int
    let images: [ShareMediaImage]

    var exists: Bool { guid != nil }

    var posterURL: URL? {
        guard let poster = images.first(where: { $0.coverType == "poster" }),
              let urlString = poster.remoteURL else { return nil }
        return URL(string: urlString)
    }

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tmdbId, title, year, images
    }
}

struct ShareSeriesResult: Identifiable, Codable {
    var id: Int { guid ?? (tvdbId + 100_000) }

    let guid: Int?
    let tvdbId: Int
    let title: String
    let year: Int
    let images: [ShareMediaImage]

    var exists: Bool { guid != nil }

    var posterURL: URL? {
        guard let poster = images.first(where: { $0.coverType == "poster" }),
              let urlString = poster.remoteURL else { return nil }
        return URL(string: urlString)
    }

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tvdbId, title, year, images
    }
}

// MARK: - API Client

enum ShareAPIClient {
    static func lookupMovies(instance: ShareInstance, query: String) async throws -> [ShareMovieResult] {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/movie/lookup")
            .appending(queryItems: [URLQueryItem(name: "term", value: query)])

        return try await request(url: url, headers: instance.auth)
    }

    static func lookupSeries(instance: ShareInstance, query: String) async throws -> [ShareSeriesResult] {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/series/lookup")
            .appending(queryItems: [URLQueryItem(name: "term", value: query)])

        return try await request(url: url, headers: instance.auth)
    }

    private static func request<T: Decodable>(url: URL, headers: [String: String]) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Search View

struct ShareSearchView<Result: Identifiable>: View {
    let query: String
    let instance: ShareInstance
    let results: [Result]?
    let error: Error?
    let isLoading: Bool
    let posterURL: (Result) -> URL?
    let title: (Result) -> String
    let year: (Result) -> Int
    let exists: (Result) -> Bool
    let onSelect: (Result) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Close") { onClose() }
                    }
                } else if let results, results.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No results found for \"\(query)\".")
                    } actions: {
                        Button("Close") { onClose() }
                    }
                } else if let results {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(results) { result in
                                SharePosterButton(
                                    posterURL: posterURL(result),
                                    title: title(result),
                                    year: year(result),
                                    exists: exists(result)
                                ) {
                                    onSelect(result)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Results")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)]
        #else
        [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)]
        #endif
    }
}

// MARK: - Poster Button

struct SharePosterButton: View {
    let posterURL: URL?
    let title: String
    let year: Int
    let exists: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                posterImage
                    .aspectRatio(CGSize(width: 150, height: 225), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomTrailing) {
                        if exists {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                        }
                    }

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if year > 0 {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderImage
                default:
                    placeholderImage
                        .overlay { ProgressView() }
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
    }
}

// MARK: - Coordinator

@MainActor
class ShareSearchCoordinator: ObservableObject {
    @Published var movieResults: [ShareMovieResult]?
    @Published var seriesResults: [ShareSeriesResult]?
    @Published var error: Error?
    @Published var isLoading = true

    func searchMovies(query: String, instance: ShareInstance) {
        Task {
            do {
                let results = try await ShareAPIClient.lookupMovies(instance: instance, query: query)
                self.movieResults = results
            } catch {
                self.error = error
            }
            self.isLoading = false
        }
    }

    func searchSeries(query: String, instance: ShareInstance) {
        Task {
            do {
                let results = try await ShareAPIClient.lookupSeries(instance: instance, query: query)
                self.seriesResults = results
            } catch {
                self.error = error
            }
            self.isLoading = false
        }
    }
}

// MARK: - Typed Search Views

struct ShareMovieSearchView: View {
    let query: String
    let instance: ShareInstance
    let onSelect: (ShareMovieResult) -> Void
    let onClose: () -> Void

    @StateObject private var coordinator = ShareSearchCoordinator()

    var body: some View {
        ShareSearchView(
            query: query,
            instance: instance,
            results: coordinator.movieResults,
            error: coordinator.error,
            isLoading: coordinator.isLoading,
            posterURL: \.posterURL,
            title: \.title,
            year: \.year,
            exists: \.exists,
            onSelect: onSelect,
            onClose: onClose
        )
        .onAppear {
            coordinator.searchMovies(query: query, instance: instance)
        }
    }
}

struct ShareSeriesSearchView: View {
    let query: String
    let instance: ShareInstance
    let onSelect: (ShareSeriesResult) -> Void
    let onClose: () -> Void

    @StateObject private var coordinator = ShareSearchCoordinator()

    var body: some View {
        ShareSearchView(
            query: query,
            instance: instance,
            results: coordinator.seriesResults,
            error: coordinator.error,
            isLoading: coordinator.isLoading,
            posterURL: \.posterURL,
            title: \.title,
            year: \.year,
            exists: \.exists,
            onSelect: onSelect,
            onClose: onClose
        )
        .onAppear {
            coordinator.searchSeries(query: query, instance: instance)
        }
    }
}
