import Foundation

extension RadarrAPI {
    static var live: Self {
        .init(fetch: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")

            var movies: [Movie] = try await API.request(url: url, instance: instance, timeout: .slow)
            movies.stamp(instance.id)
            return movies
        }, lookup: { instance, query in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, releases: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/release")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance, timeout: .releaseSearch)
        }, movie: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")
                .appending(path: String(movieId))

            var movie: Movie = try await API.request(url: url, instance: instance)
            movie.stamp(instance.id)
            return movie
        }, history: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/history/movie")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance)
        }, files: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/moviefile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance)
        }, extraFiles: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/extrafile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance)
        }, add: { movie, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")

            return try await API.request(method: .post, url: url, body: movie, instance: instance)
        }, update: { movie, moveFiles, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie/editor")

            let body = MovieEditorResource(
                movieIds: [movie.id],
                monitored: movie.monitored,
                qualityProfileId: movie.qualityProfileId,
                minimumAvailability: movie.minimumAvailability,
                rootFolderPath: movie.rootFolderPath,
                tags: movie.tags,
                applyTags: "replace",
                moveFiles: moveFiles ? true : nil
            )

            return try await API.request(method: .put, url: url, body: body, instance: instance)
        }, delete: { movie, addExclusion, deleteFildes, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")
                .appending(path: String(movie.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: deleteFildes ? "true" : "false"),
                    .init(name: "addImportExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await API.request(method: .delete, url: url, instance: instance)
        }, deleteFile: { file, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/moviefile")
                .appending(path: String(file.id))

            return try await API.request(method: .delete, url: url, instance: instance)
        }, calendar: { start, end, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var movies: [Movie] = try await API.request(url: url, instance: instance, timeout: .slow)
            movies.stamp(instance.id)
            return movies
        })
    }
}
