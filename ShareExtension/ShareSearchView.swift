import SwiftUI
import NukeUI

// MARK: - Lightweight API Models

struct ShareRating: Codable {
    let votes: Int
    let value: Double
}

struct ShareMovieRatings: Codable {
    let imdb: ShareRating?
    let tmdb: ShareRating?
    let rottenTomatoes: ShareRating?
}

struct ShareMovieResult: Identifiable {
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
    let images: [MediaImage]

    // Raw JSON for POST back to API
    let rawJSON: [String: Any]

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
}

struct ShareSeriesResult: Identifiable {
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
    let ratings: ShareRating?
    let status: String?
    let ended: Bool?
    let monitored: Bool?
    let images: [MediaImage]

    // Raw JSON for POST back to API
    let rawJSON: [String: Any]

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
}

// MARK: - API Client

enum ShareAPIClient {
    static func lookupMovies(instance: Instance, query: String) async throws -> [ShareMovieResult] {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/movie/lookup")
            .appending(queryItems: [URLQueryItem(name: "term", value: query)])

        let data = try await rawRequest(url: url, headers: instance.auth)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return array.compactMap { dict in
            guard let itemData = try? JSONSerialization.data(withJSONObject: dict),
                  let partial = try? decoder.decode(MoviePartial.self, from: itemData) else {
                return nil
            }
            return ShareMovieResult(
                guid: partial.guid, tmdbId: partial.tmdbId, title: partial.title,
                year: partial.year, runtime: partial.runtime, overview: partial.overview,
                certification: partial.certification, studio: partial.studio,
                genres: partial.genres, ratings: partial.ratings, status: partial.status,
                monitored: partial.monitored, hasFile: partial.hasFile,
                images: partial.images, rawJSON: dict
            )
        }
    }

    static func lookupSeries(instance: Instance, query: String) async throws -> [ShareSeriesResult] {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/series/lookup")
            .appending(queryItems: [URLQueryItem(name: "term", value: query)])

        let data = try await rawRequest(url: url, headers: instance.auth)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return array.compactMap { dict in
            guard let itemData = try? JSONSerialization.data(withJSONObject: dict),
                  let partial = try? decoder.decode(SeriesPartial.self, from: itemData) else {
                return nil
            }
            return ShareSeriesResult(
                guid: partial.guid, tvdbId: partial.tvdbId, title: partial.title,
                year: partial.year, runtime: partial.runtime, overview: partial.overview,
                certification: partial.certification, network: partial.network,
                genres: partial.genres, ratings: partial.ratings, status: partial.status,
                ended: partial.ended, monitored: partial.monitored,
                images: partial.images, rawJSON: dict
            )
        }
    }

    static func fetchRootFolders(instance: Instance) async throws -> [InstanceRootFolder] {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/rootfolder")
        return try await request(url: url, headers: instance.auth)
    }

    static func fetchQualityProfiles(instance: Instance) async throws -> [InstanceQualityProfile] {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/qualityprofile")
        return try await request(url: url, headers: instance.auth)
    }

    static func addMovie(rawJSON: [String: Any], overrides: [String: Any], instance: Instance) async throws {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/movie")

        var body = rawJSON
        for (key, value) in overrides {
            body[key] = value
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        try await postRequest(url: url, headers: instance.auth, body: data)
    }

    static func addSeries(rawJSON: [String: Any], overrides: [String: Any], instance: Instance) async throws {
        let url = try instance.baseURL()
            .appending(path: "/api/v3/series")

        var body = rawJSON
        for (key, value) in overrides {
            body[key] = value
        }

        let data = try JSONSerialization.data(withJSONObject: body)
        try await postRequest(url: url, headers: instance.auth, body: data)
    }

    // MARK: - HTTP Helpers

    private static func rawRequest(url: URL, headers: [String: String]) async throws -> Data {
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

        return data
    }

    private static func request<T: Decodable>(url: URL, headers: [String: String]) async throws -> T {
        let data = try await rawRequest(url: url, headers: headers)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    @discardableResult
    private static func postRequest(url: URL, headers: [String: String], body: Data) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse,
               let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = payload["message"] as? String {
                throw ShareAPIError.serverError(code: httpResponse.statusCode, message: message)
            }
            throw URLError(.badServerResponse)
        }

        return data
    }
}

// MARK: - Decodable partials (for lookup parsing)

private struct MoviePartial: Decodable {
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
    let images: [MediaImage]

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tmdbId, title, year, runtime, overview, certification
        case studio, genres, ratings, status, monitored, hasFile, images
    }
}

private struct SeriesPartial: Decodable {
    let guid: Int?
    let tvdbId: Int
    let title: String
    let year: Int
    let runtime: Int
    let overview: String?
    let certification: String?
    let network: String?
    let genres: [String]
    let ratings: ShareRating?
    let status: String?
    let ended: Bool?
    let monitored: Bool?
    let images: [MediaImage]

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case tvdbId, title, year, runtime, overview, certification
        case network, genres, ratings, status, ended, monitored, images
    }
}

enum ShareAPIError: LocalizedError {
    case serverError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .serverError(_, let message): return message
        }
    }
}

// MARK: - Search Coordinator

@MainActor
class ShareSearchCoordinator: ObservableObject {
    @Published var movieResults: [ShareMovieResult]?
    @Published var seriesResults: [ShareSeriesResult]?
    @Published var error: Error?
    @Published var isLoading = true

    func searchMovies(query: String, instance: Instance) {
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

    func searchSeries(query: String, instance: Instance) {
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

// MARK: - Instance Config (fetched for add form)

@MainActor
class InstanceConfig: ObservableObject {
    @Published var rootFolders: [InstanceRootFolder] = []
    @Published var qualityProfiles: [InstanceQualityProfile] = []
    @Published var isLoaded = false
    @Published var error: Error?

    func fetch(instance: Instance) {
        guard !isLoaded else { return }
        Task {
            do {
                async let folders = ShareAPIClient.fetchRootFolders(instance: instance)
                async let profiles = ShareAPIClient.fetchQualityProfiles(instance: instance)
                self.rootFolders = try await folders
                self.qualityProfiles = try await profiles
                self.isLoaded = true
            } catch {
                self.error = error
            }
        }
    }
}

// MARK: - Movie Search View

struct ShareMovieSearchView: View {
    let query: String
    let instance: Instance
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
                ShareMoviePreviewView(movie: movie, instance: instance) {
                    selectedMovie = nil
                    onClose()
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
    let instance: Instance
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
                ShareSeriesPreviewView(series: series, instance: instance) {
                    selectedSeries = nil
                    onClose()
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
                .background(.quaternary)
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
            LazyImage(url: posterURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                        .overlay { state.isLoading ? ProgressView() : nil }
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
    let instance: Instance
    let onAdded: () -> Void
    let onClose: () -> Void

    @StateObject private var config = InstanceConfig()

    @State private var presentingForm = false
    @State private var isAdding = false
    @State private var addError: Error?
    @State private var descriptionExpanded = false

    // Form state
    @State private var qualityProfileId: Int = 0
    @State private var rootFolderPath: String = ""
    @State private var monitorType: String = "movieOnly"
    @State private var minimumAvailability: String = "announced"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header.padding(.bottom)
                    details.padding(.bottom)

                    if let overview = movie.overview, !overview.isEmpty {
                        descriptionView(overview).padding(.bottom)
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
                        Label("Already Added", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    } else {
                        Button("Add Movie", systemImage: "plus") {
                            presentingForm = true
                        }
                    }
                }
            }
            .sheet(isPresented: $presentingForm) {
                addFormSheet
            }
            .alert("Failed to Add", isPresented: Binding(
                get: { addError != nil },
                set: { if !$0 { addError = nil } }
            )) {
                Button("OK") { addError = nil }
            } message: {
                if let error = addError {
                    Text(error.localizedDescription)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        .onAppear {
            config.fetch(instance: instance)
        }
    }

    private var addFormSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Monitor", selection: $monitorType) {
                        Text("Movie").tag("movieOnly")
                        Text("Movie + Collection").tag("movieAndCollection")
                        Text("None").tag("none")
                    }

                    Picker("Minimum Availability", selection: $minimumAvailability) {
                        Text("Announced").tag("announced")
                        Text("In Cinemas").tag("inCinemas")
                        Text("Released").tag("released")
                    }

                    if config.qualityProfiles.count > 1 {
                        Picker("Quality Profile", selection: $qualityProfileId) {
                            ForEach(config.qualityProfiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    }
                }

                if config.rootFolders.count > 1 {
                    Picker("Root Folder", selection: $rootFolderPath) {
                        ForEach(config.rootFolders) { folder in
                            Text(folder.label).tag(folder.path ?? "")
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Movie")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentingForm = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await addMovie() }
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(isAdding)
                }
            }
            .onAppear { selectDefaults() }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private func selectDefaults() {
        qualityProfileId = config.qualityProfiles.first?.id ?? 0
        rootFolderPath = config.rootFolders.first?.path ?? ""
    }

    private func addMovie() async {
        isAdding = true
        defer { isAdding = false }

        let overrides: [String: Any] = [
            "monitored": monitorType != "none",
            "qualityProfileId": qualityProfileId,
            "rootFolderPath": rootFolderPath,
            "minimumAvailability": minimumAvailability,
            "addOptions": ["monitor": monitorType],
        ]

        do {
            try await ShareAPIClient.addMovie(
                rawJSON: movie.rawJSON,
                overrides: overrides,
                instance: instance
            )
            presentingForm = false
            onAdded()
        } catch {
            presentingForm = false
            addError = error
        }
    }

    // MARK: - Preview Layout

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
            if movie.year > 0 { Text(String(movie.year)) }
            if !movie.runtimeLabel.isEmpty { Text("  \(movie.runtimeLabel)") }
            if let cert = movie.certification, !cert.isEmpty { Text("  \(cert)") }
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

    private func descriptionView(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text(text)
                .font(.callout)
                .lineLimit(descriptionExpanded ? nil : 4)
                .onTapGesture { withAnimation(.snappy) { descriptionExpanded = true } }
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
        if let url = movie.posterURL {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    posterPlaceholder
                        .overlay { state.isLoading ? ProgressView() : nil }
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle().fill(.quaternary).overlay {
            Text(movie.title).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(4)
        }
    }
}

// MARK: - Series Preview View

struct ShareSeriesPreviewView: View {
    let series: ShareSeriesResult
    let instance: Instance
    let onAdded: () -> Void
    let onClose: () -> Void

    @StateObject private var config = InstanceConfig()

    @State private var presentingForm = false
    @State private var isAdding = false
    @State private var addError: Error?
    @State private var descriptionExpanded = false

    // Form state
    @State private var qualityProfileId: Int = 0
    @State private var rootFolderPath: String = ""
    @State private var monitorType: String = "all"
    @State private var seasonFolder: Bool = true
    @State private var seriesType: String = "standard"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    header.padding(.bottom)
                    details.padding(.bottom)

                    if let overview = series.overview, !overview.isEmpty {
                        descriptionView(overview).padding(.bottom)
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
                        Label("Already Added", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    } else {
                        Button("Add Series", systemImage: "plus") {
                            presentingForm = true
                        }
                    }
                }
            }
            .sheet(isPresented: $presentingForm) {
                addFormSheet
            }
            .alert("Failed to Add", isPresented: Binding(
                get: { addError != nil },
                set: { if !$0 { addError = nil } }
            )) {
                Button("OK") { addError = nil }
            } message: {
                if let error = addError {
                    Text(error.localizedDescription)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        .onAppear {
            config.fetch(instance: instance)
        }
    }

    private var addFormSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Monitor", selection: $monitorType) {
                        Text("All Episodes").tag("all")
                        Text("Future Episodes").tag("future")
                        Text("Missing Episodes").tag("missing")
                        Text("Existing Episodes").tag("existing")
                        Text("Recent Episodes").tag("recent")
                        Text("Pilot Episode").tag("pilot")
                        Text("First Season").tag("firstSeason")
                        Text("Last Season").tag("lastSeason")
                        Text("None").tag("none")
                    }

                    if config.qualityProfiles.count > 1 {
                        Picker("Quality Profile", selection: $qualityProfileId) {
                            ForEach(config.qualityProfiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    }

                    Picker("Series Type", selection: $seriesType) {
                        Text("Standard").tag("standard")
                        Text("Daily").tag("daily")
                        Text("Anime").tag("anime")
                    }

                    Toggle("Season Folders", isOn: $seasonFolder)
                }

                if config.rootFolders.count > 1 {
                    Picker("Root Folder", selection: $rootFolderPath) {
                        ForEach(config.rootFolders) { folder in
                            Text(folder.label).tag(folder.path ?? "")
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Series")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentingForm = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await addSeries() }
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(isAdding)
                }
            }
            .onAppear { selectDefaults() }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private func selectDefaults() {
        qualityProfileId = config.qualityProfiles.first?.id ?? 0
        rootFolderPath = config.rootFolders.first?.path ?? ""
    }

    private func addSeries() async {
        isAdding = true
        defer { isAdding = false }

        let overrides: [String: Any] = [
            "monitored": monitorType != "none",
            "qualityProfileId": qualityProfileId,
            "rootFolderPath": rootFolderPath,
            "seriesType": seriesType,
            "seasonFolder": seasonFolder,
            "addOptions": ["monitor": monitorType],
        ]

        do {
            try await ShareAPIClient.addSeries(
                rawJSON: series.rawJSON,
                overrides: overrides,
                instance: instance
            )
            presentingForm = false
            onAdded()
        } catch {
            presentingForm = false
            addError = error
        }
    }

    // MARK: - Preview Layout

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
            if series.year > 0 { Text(String(series.year)) }
            if !series.runtimeLabel.isEmpty { Text("  \(series.runtimeLabel)/ep") }
            if let cert = series.certification, !cert.isEmpty { Text("  \(cert)") }
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

    private func descriptionView(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text(text)
                .font(.callout)
                .lineLimit(descriptionExpanded ? nil : 4)
                .onTapGesture { withAnimation(.snappy) { descriptionExpanded = true } }
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
        if let url = series.posterURL {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    posterPlaceholder
                        .overlay { state.isLoading ? ProgressView() : nil }
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle().fill(.quaternary).overlay {
            Text(series.title).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(4)
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
