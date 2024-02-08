import Foundation

extension API {
    static var mock: Self {
        .init(fetchMovies: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "movies")
        }, lookupMovies: { _, query in
            let movies: [Movie] = loadPreviewData(filename: "movie-lookup")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return movies.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }, lookupReleases: { _, _ in
            try await Task.sleep(nanoseconds: 1_500_000_000)

            return loadPreviewData(filename: "releases")
        }, downloadRelease: { _, _, _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return Empty()
        }, getMovie: { movieId, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return movies.first(where: { $0.movieId == movieId })!
        }, addMovie: { _, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return movies[0]
        }, updateMovie: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        }, deleteMovie: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        }, command: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        }, systemStatus: { _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return loadPreviewData(filename: "system-status")
        }, rootFolders: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "root-folders")
        }, qualityProfiles: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "quality-profiles")
        })
    }
}

fileprivate extension API {
    static func loadPreviewData<Model: Decodable>(filename: String) -> Model {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                return try decoder.decode(Model.self, from: data)
            } catch {
                fatalError("Preview data `\(filename)` could not be decoded")
            }
        }

        fatalError("Preview data `\(filename)` not found")
    }
}
