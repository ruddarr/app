import Foundation

extension API {
    static var mock: Self {
        .init(fetchMovies: { _ in
           loadPreviewData(filename: "movies")
        }, lookupMovies: { _, query in
            let movies: [Movie] = loadPreviewData(filename: "movie-lookup")
            try await Task.sleep(nanoseconds: UInt64(1.5 * Double(NSEC_PER_SEC)))

            return movies.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }, getMovie: { movieId, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")

            return movies.first(where: { $0.movieId == movieId })!
        }, addMovie: { _, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(nanoseconds: UInt64(1.5 * Double(NSEC_PER_SEC)))

            return movies[0]
        }, updateMovie: { _, _ in
            try await Task.sleep(nanoseconds: UInt64(1.5 * Double(NSEC_PER_SEC)))

            return Empty()
        }, deleteMovie: { _, _ in
            try await Task.sleep(nanoseconds: UInt64(1.5 * Double(NSEC_PER_SEC)))

            return Empty()
        }, command: { _, _ in
            return Empty()
        }, systemStatus: { _ in
            loadPreviewData(filename: "system-status")
        }, rootFolders: { _ in
            loadPreviewData(filename: "root-folders")
        }, qualityProfiles: { _ in
            loadPreviewData(filename: "quality-profiles")
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
