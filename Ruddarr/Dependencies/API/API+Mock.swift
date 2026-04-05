import Foundation

extension API {
    static var mock: Self {
        .init(fetchMovies: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "movies")
        }, lookupMovies: { _, query in
            let movies: [Movie] = loadPreviewData(filename: "movie-lookup")
            try await Task.sleep(for: .seconds(1))

            return movies.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }, lookupMovieReleases: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "movie-releases")
        }, getMovie: { movieId, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(for: .seconds(2))

            return movies.first(where: { $0.guid == movieId })!
        }, getMovieHistory: { _, _ in
            let events: [MediaHistoryEvent] = loadPreviewData(filename: "movie-history")
            try await Task.sleep(for: .seconds(1))

            return events
        }, getMovieFiles: { _, _ in
            let files: [MediaFile] = loadPreviewData(filename: "movie-files")
            try await Task.sleep(for: .seconds(1))

            return files
        }, getMovieExtraFiles: { _, _ in
            let files: [MovieExtraFile] = loadPreviewData(filename: "movie-extra-files")
            // try await Task.sleep(for: .seconds(1))

            return files
        }, addMovie: { _, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(for: .seconds(2))

            return movies[0]
        }, updateMovie: { _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, deleteMovie: { _, _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, deleteMovieFile: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, fetchSeries: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series")
        }, fetchEpisodes: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return loadPreviewData(filename: "series-episodes")
        }, fetchEpisodeFiles: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series-episode-files")
        }, lookupSeries: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series-lookup")
        }, lookupSeriesReleases: { _, _, _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series-releases")
        }, getSeries: { _, _ in
            let series: [Series] = loadPreviewData(filename: "series")
            try await Task.sleep(for: .seconds(1))

            return series[0]
        }, addSeries: { _, _ in
            let series: [Series] = loadPreviewData(filename: "series")
            try await Task.sleep(for: .seconds(2))

            return series[0]
        }, pushSeries: { _, _ in
            let series: [Series] = loadPreviewData(filename: "series")
            try await Task.sleep(for: .seconds(2))

            return series[0]
        }, updateSeries: { _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, deleteSeries: { _, _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, monitorEpisode: { _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, getEpisodeHistory: { _, _ in
            let events: MediaHistory = loadPreviewData(filename: "series-episode-history")
            try await Task.sleep(for: .seconds(2))

            return events
        }, deleteEpisodeFile: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, deleteEpisodeFiles: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        }, movieCalendar: { _, _, instance in
            try await Task.sleep(for: .seconds(2))
            let movies: [Movie] = loadPreviewData(filename: "calendar-movies")

            return modifyCalendarMovies(movies, instance)
        }, episodeCalendar: { _, _, instance in
            try await Task.sleep(for: .seconds(3))
            let episodes: [Episode] = loadPreviewData(filename: "calendar-episodes")

            return modifyCalendarEpisodes(episodes, instance)
        }, command: { cmd, instance in
            var status = InstanceCommandStatus(
                id: Int.random(in: 1...999),
                name: cmd.payload.name,
                commandName: nil,
                message: "Queued",
                status: "queued",
                result: nil,
                queued: Date(),
                started: nil,
                ended: nil,
                trigger: "manual",
                instanceId: nil,
                subject: nil
            )
            status.instanceId = instance.id
            return status
        }, fetchCommand: { id, instance in
            var status = InstanceCommandStatus(
                id: id,
                name: "MoviesSearch",
                commandName: nil,
                message: "Completed",
                status: "completed",
                result: "successful",
                queued: Date().addingTimeInterval(-10),
                started: Date().addingTimeInterval(-9),
                ended: Date().addingTimeInterval(-1),
                trigger: "manual",
                instanceId: nil,
                subject: nil
            )
            status.instanceId = instance.id
            return status
        }, fetchCommands: { _ in
            []
        }, downloadRelease: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return Empty()
        }, systemStatus: { instance in
            try await Task.sleep(for: .seconds(2))

            return InstanceStatus(
                appName: instance.type.rawValue.capitalized,
                instanceName: "Synology",
                version: "5.2.6.8376"
            )
        }, rootFolders: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "root-folders")
        }, qualityProfiles: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "quality-profiles")
        }, getTags: { _ in
            try await Task.sleep(for: .seconds(1))
            let tags: [Tag] = loadPreviewData(filename: "tags")
            return tags
        }, fetchQueueTasks: { instance in
            try await Task.sleep(for: .seconds(1))

            let items: QueueItems = loadPreviewData(
                filename: instance.type == .sonarr ? "series-queue" : "movie-queue"
            )

            return modifyQueueItems(items, instance)
        }, deleteQueueTask: { _, _, _, _, _ in
            try await Task.sleep(for: .seconds(3))

            return Empty()
        }, fetchImportableFiles: { _, instance in
            try await Task.sleep(for: .seconds(1))

            let files: [ImportableFile] = loadPreviewData(
                filename: instance.type == .sonarr ? "sonarr-manual-import" : "radarr-manual-import"
            )

            return files
        }, fetchHistory: { _, _, _, instance in
            try await Task.sleep(for: .seconds(2))

            let events: MediaHistory = loadPreviewData(
                filename: instance.type == .sonarr ? "sonarr-history" : "radarr-history"
            )

            return events
        }, fetchNotifications: { _ in
            try await Task.sleep(for: .seconds(2))

            return loadPreviewData(filename: "notifications")
        }, createNotification: { _, _ in
            let notifications: [InstanceNotification] = loadPreviewData(filename: "notifications")
            try await Task.sleep(for: .seconds(2))

            return notifications[0]
        }, updateNotification: { _, _ in
            let notifications: [InstanceNotification] = loadPreviewData(filename: "notifications")
            try await Task.sleep(for: .seconds(2))

            return notifications[0]
        }, deleteNotification: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return Empty()
        })
    }
}

fileprivate extension API {
    static func loadPreviewData<Model: Decodable>(filename: String) -> Model {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601extended

                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                return try decoder.decode(Model.self, from: data)
            } catch {
                fatalError("Preview data `\(filename)` could not be decoded: \(error)")
            }
        }

        fatalError("Preview data `\(filename)` not found")
    }
}

private func modifyQueueItems(_ items: QueueItems, _ instance: Instance) -> QueueItems {
    var modifiedItems = items

    modifiedItems.records = items.records.map { record in
        var record = record

        record.instanceId = instance.id

        // set `estimatedCompletionTime` to be in the future for testing
        if let timeLeft = record.timeleft {
            record.estimatedCompletionTime = Date().addingTimeInterval(TimeInterval(
                timeLeft.split(separator: ":").reversed().enumerated().reduce(0) {
                    $0 + (Int($1.element) ?? 0) * Int(pow(60, Double($1.offset)))
                }
            ))
        }

        return record
    }

    return modifiedItems
}

private func modifyCalendarMovies(_ items: [Movie], _ instance: Instance) -> [Movie] {
    let date = Calendar.current.date(from: DateComponents(year: 2_026, month: 1, day: 30, hour: 12))
    let days = Calendar.current.dateComponents([.day], from: date!, to: .now).day!

    return items.map { item in
        var movie = item

        movie.instanceId = instance.id

        if let inCinemas = item.inCinemas {
            movie.inCinemas = Calendar.current.date(byAdding: .day, value: Int(days), to: inCinemas)!
        }

        if let physicalRelease = item.physicalRelease {
            movie.physicalRelease = Calendar.current.date(byAdding: .day, value: Int(days), to: physicalRelease)!
        }

        if let digitalRelease = item.digitalRelease {
            movie.digitalRelease = Calendar.current.date(byAdding: .day, value: Int(days), to: digitalRelease)!
        }

        return movie
    }
}

private func modifyCalendarEpisodes(_ items: [Episode], _ instance: Instance) -> [Episode] {
    let date = Calendar.current.date(from: DateComponents(year: 2_026, month: 1, day: 30, hour: 12))
    let days = Calendar.current.dateComponents([.day], from: date!, to: .now).day!

    return items.map { item in
        var episode = item

        episode.instanceId = instance.id

        if let airDateUtc = item.airDateUtc {
            episode.airDateUtc = Calendar.current.date(byAdding: .day, value: Int(days), to: airDateUtc)!
        }

        return episode
    }
}
