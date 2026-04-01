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

struct ShareRating: Codable {
    let votes: Int
    let value: Double
}

struct ShareMovieRatings: Codable {
    let imdb: ShareRating?
    let tmdb: ShareRating?
    let rottenTomatoes: ShareRating?
}

struct ShareMovieResult: Identifiable, Codable {
    var id: Int { guid ?? (tmdbId + 100_000) }

    let guid: Int?
    let tmdbId: Int
    let title: String
    let year: Int
    let runtime: Int
    let overview: String?
    let certification: String?
    let studio: String?
    let genres: [String]
    let ratings: ShareMovieRatings?
    let status: String?
    let monitored: Bool?
    let hasFile: Bool?
    let images: [ShareMediaImage]

    var exists: Bool { guid != nil }
    var isDownloaded: Bool { hasFile ?? false }

    var posterURL: URL? {
        guard let poster = images.first(where: { $0.coverType == "poster" }),
              let urlString = poster.remoteURL else { return nil }
        return URL(string: urlString)
    }

    var runtimeLabel: String {
        guard runtime > 0 else { return "" }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var genreLabel: String {
        genres.prefix(3).joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tmdbId, title, year, runtime, overview, certification
        case studio, genres, ratings, status, monitored, hasFile, images
    }
}

struct ShareSeriesRatings: Codable {
    let votes: Int
    let value: Double
}

struct ShareSeriesResult: Identifiable, Codable {
    var id: Int { guid ?? (tvdbId + 100_000) }

    let guid: Int?
    let tvdbId: Int
    let title: String
    let year: Int
    let runtime: Int
    let overview: String?
    let certification: String?
    let network: String?
    let genres: [String]
    let ratings: ShareSeriesRatings?
    let status: String?
    let ended: Bool?
    let monitored: Bool?
    let images: [ShareMediaImage]

    var exists: Bool { guid != nil }

    var posterURL: URL? {
        guard let poster = images.first(where: { $0.coverType == "poster" }),
              let urlString = poster.remoteURL else { return nil }
        return URL(string: urlString)
    }

    var runtimeLabel: String {
        guard runtime > 0 else { return "" }
        return "\(runtime)m"
    }

    var genreLabel: String {
        genres.prefix(3).joined(separator: ", ")
    }

    var statusLabel: String {
        guard let status else { return "" }
        return status.prefix(1).uppercased() + status.dropFirst()
    }

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tvdbId, title, year, runtime, overview, certification
        case network, genres, ratings, status, ended, monitored, images
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

// MARK: - Search Coordinator

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

// MARK: - Movie Search View

struct ShareMovieSearchView: View {
    let query: String
    let instance: ShareInstance
    let onOpenInApp: (ShareMovieResult) -> Void
    let onClose: () -> Void

    @StateObject private var coordinator = ShareSearchCoordinator()
    @State private var selectedMovie: ShareMovieResult?

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = coordinator.error {
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Close") { onClose() }
                    }
                } else if let results = coordinator.movieResults, results.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No results found for \"\(query)\".")
                    } actions: {
                        Button("Close") { onClose() }
                    }
                } else if let results = coordinator.movieResults {
                    ScrollView {
                        LazyVGrid(columns: posterColumns, spacing: posterSpacing) {
                            ForEach(results) { movie in
                                ShareGridPoster(
                                    posterURL: movie.posterURL,
                                    title: movie.title,
                                    exists: movie.exists,
                                    isDownloaded: movie.isDownloaded,
                                    monitored: movie.monitored ?? false
                                ) {
                                    selectedMovie = movie
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
            .sheet(item: $selectedMovie) { movie in
                ShareMoviePreviewView(movie: movie) {
                    selectedMovie = nil
                    onOpenInApp(movie)
                } onClose: {
                    selectedMovie = nil
                }
            }
        }
        .onAppear {
            coordinator.searchMovies(query: query, instance: instance)
        }
    }
}

// MARK: - Series Search View

struct ShareSeriesSearchView: View {
    let query: String
    let instance: ShareInstance
    let onOpenInApp: (ShareSeriesResult) -> Void
    let onClose: () -> Void

    @StateObject private var coordinator = ShareSearchCoordinator()
    @State private var selectedSeries: ShareSeriesResult?

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.isLoading {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = coordinator.error {
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Close") { onClose() }
                    }
                } else if let results = coordinator.seriesResults, results.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No results found for \"\(query)\".")
                    } actions: {
                        Button("Close") { onClose() }
                    }
                } else if let results = coordinator.seriesResults {
                    ScrollView {
                        LazyVGrid(columns: posterColumns, spacing: posterSpacing) {
                            ForEach(results) { series in
                                ShareGridPoster(
                                    posterURL: series.posterURL,
                                    title: series.title,
                                    exists: series.exists,
                                    isDownloaded: false,
                                    monitored: series.monitored ?? false
                                ) {
                                    selectedSeries = series
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
            .sheet(item: $selectedSeries) { series in
                ShareSeriesPreviewView(series: series) {
                    selectedSeries = nil
                    onOpenInApp(series)
                } onClose: {
                    selectedSeries = nil
                }
            }
        }
        .onAppear {
            coordinator.searchSeries(query: query, instance: instance)
        }
    }
}

// MARK: - Grid Poster (matches main app style)

struct ShareGridPoster: View {
    let posterURL: URL?
    let title: String
    let exists: Bool
    let isDownloaded: Bool
    let monitored: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            posterImage
                .aspectRatio(CGSize(width: 150, height: 225), contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray5))
                .overlay(alignment: .bottom) {
                    if exists {
                        posterOverlay
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder
                default:
                    placeholder.overlay { ProgressView() }
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
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

    private var posterOverlay: some View {
        HStack {
            Group {
                if isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .foregroundStyle(.white)
            .font(.caption)

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(monitored ? .fill : .none)
                .foregroundStyle(.white)
                .font(.caption)
        }
        .padding(.top, 36)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Movie Preview View

struct ShareMoviePreviewView: View {
    let movie: ShareMovieResult
    let onAdd: () -> Void
    let onClose: () -> Void

    @State private var descriptionExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)

                    details
                        .padding(.bottom)

                    if let overview = movie.overview, !overview.isEmpty {
                        description(overview)
                            .padding(.bottom)
                    }
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if movie.exists {
                        Button("Open in Ruddarr", systemImage: "arrow.up.forward.app") {
                            onAdd()
                        }
                    } else {
                        Button("Add Movie", systemImage: "plus") {
                            onAdd()
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            posterImage
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(3)

                subtitleText

                if let ratings = movie.ratings {
                    ratingsView(ratings)
                }

                Spacer()
            }
        }
    }

    private var subtitleText: some View {
        HStack(spacing: 4) {
            if movie.year > 0 {
                Text(String(movie.year))
            }
            if !movie.runtimeLabel.isEmpty {
                Text("  \(movie.runtimeLabel)")
            }
            if let cert = movie.certification, !cert.isEmpty {
                Text("  \(cert)")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func ratingsView(_ ratings: ShareMovieRatings) -> some View {
        HStack(spacing: 12) {
            if let imdb = ratings.imdb, imdb.votes > 0 {
                Label(String(format: "%.1f", imdb.value), systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
            if let rt = ratings.rottenTomatoes, rt.votes > 0 {
                Label("\(Int(rt.value))%", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline)
    }

    private var details: some View {
        Grid(alignment: .leading) {
            if let status = movie.status, !status.isEmpty {
                detailRow("Status", value: status.prefix(1).uppercased() + status.dropFirst())
            }
            if let studio = movie.studio, !studio.isEmpty {
                detailRow("Studio", value: studio)
            }
            if !movie.genreLabel.isEmpty {
                detailRow("Genre", value: movie.genreLabel)
            }
        }
    }

    private func description(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text(text)
                .font(.callout)
                .lineLimit(descriptionExpanded ? nil : 4)
                .onTapGesture {
                    withAnimation(.snappy) { descriptionExpanded = true }
                }
            Spacer()
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        GridRow(alignment: .top) {
            Text(label)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .padding(.trailing)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let posterURL = movie.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    posterPlaceholder
                default:
                    posterPlaceholder.overlay { ProgressView() }
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Text(movie.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
    }
}

// MARK: - Series Preview View

struct ShareSeriesPreviewView: View {
    let series: ShareSeriesResult
    let onAdd: () -> Void
    let onClose: () -> Void

    @State private var descriptionExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)

                    details
                        .padding(.bottom)

                    if let overview = series.overview, !overview.isEmpty {
                        description(overview)
                            .padding(.bottom)
                    }
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if series.exists {
                        Button("Open in Ruddarr", systemImage: "arrow.up.forward.app") {
                            onAdd()
                        }
                    } else {
                        Button("Add Series", systemImage: "plus") {
                            onAdd()
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            posterImage
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(series.title)
                    .font(.headline)
                    .lineLimit(3)

                subtitleText

                if let ratings = series.ratings, ratings.votes > 0 {
                    Label(String(format: "%.0f%%", ratings.value * 10), systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                }

                Spacer()
            }
        }
    }

    private var subtitleText: some View {
        HStack(spacing: 4) {
            if series.year > 0 {
                Text(String(series.year))
            }
            if !series.runtimeLabel.isEmpty {
                Text("  \(series.runtimeLabel)/ep")
            }
            if let cert = series.certification, !cert.isEmpty {
                Text("  \(cert)")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var details: some View {
        Grid(alignment: .leading) {
            if !series.statusLabel.isEmpty {
                detailRow("Status", value: series.statusLabel)
            }
            if let network = series.network, !network.isEmpty {
                detailRow("Network", value: network)
            }
            if !series.genreLabel.isEmpty {
                detailRow("Genre", value: series.genreLabel)
            }
        }
    }

    private func description(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text(text)
                .font(.callout)
                .lineLimit(descriptionExpanded ? nil : 4)
                .onTapGesture {
                    withAnimation(.snappy) { descriptionExpanded = true }
                }
            Spacer()
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        GridRow(alignment: .top) {
            Text(label)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .padding(.trailing)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let posterURL = series.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    posterPlaceholder
                default:
                    posterPlaceholder.overlay { ProgressView() }
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Text(series.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
    }
}

// MARK: - Grid Layout Helpers

private var posterColumns: [GridItem] {
    #if os(macOS)
    [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]
    #else
    [GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)]
    #endif
}

private var posterSpacing: CGFloat {
    #if os(macOS)
    20
    #else
    12
    #endif
}
