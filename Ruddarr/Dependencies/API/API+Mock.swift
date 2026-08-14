import Foundation

extension API {
    static var mock: Self {
        .init(radarr: .mock, sonarr: .mock, instance: .mock)
    }
}

extension RadarrAPI {
    static var mock: Self {
        .init(fetch: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "movies")
        }, lookup: { _, query in
            let movies: [Movie] = loadPreviewData(filename: "movie-lookup")
            try await Task.sleep(for: .seconds(1))

            return movies.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }, releases: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "movie-releases")
        }, movie: { movieId, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(for: .seconds(2))

            return movies.first(where: { $0.guid == movieId })!
        }, history: { _, _ in
            let events: [MediaHistoryEvent] = loadPreviewData(filename: "movie-history")
            try await Task.sleep(for: .seconds(1))

            return events
        }, files: { _, _ in
            let files: [MediaFile] = loadPreviewData(filename: "movie-files")
            try await Task.sleep(for: .seconds(1))

            return files
        }, extraFiles: { _, _ in
            let files: [MovieExtraFile] = loadPreviewData(filename: "movie-extra-files")
            // try await Task.sleep(for: .seconds(1))

            return files
        }, add: { _, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(for: .seconds(2))

            return movies[0]
        }, update: { _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, delete: { _, _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, deleteFile: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, calendar: { _, _, instance in
            try await Task.sleep(for: .seconds(2))
            let movies: [Movie] = loadPreviewData(filename: "calendar-movies")

            return modifyCalendarMovies(movies, instance)
        })
    }
}

extension SonarrAPI {
    static var mock: Self {
        .init(fetch: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series")
        }, episodes: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return loadPreviewData(filename: "series-episodes")
        }, lookup: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series-lookup")
        }, releases: { _, _, _, _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "series-releases")
        }, series: { _, _ in
            let series: [Series] = loadPreviewData(filename: "series")
            try await Task.sleep(for: .seconds(1))

            return series[0]
        }, add: { _, _ in
            let series: [Series] = loadPreviewData(filename: "series")
            try await Task.sleep(for: .seconds(2))

            return series[0]
        }, push: { _, _ in
            let series: [Series] = loadPreviewData(filename: "series")
            try await Task.sleep(for: .seconds(2))

            return series[0]
        }, update: { _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, delete: { _, _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, monitorEpisode: { _, _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, episodeHistory: { _, _ in
            let events: MediaHistory = loadPreviewData(filename: "series-episode-history")
            try await Task.sleep(for: .seconds(2))

            return events
        }, deleteEpisodeFile: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, deleteEpisodeFiles: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, calendar: { _, _, instance in
            try await Task.sleep(for: .seconds(3))
            let episodes: [Episode] = loadPreviewData(filename: "calendar-episodes")

            return modifyCalendarEpisodes(episodes, instance)
        })
    }
}

extension InstanceAPI {
    static var mock: Self {
        .init(command: { _, _ in
            try await Task.sleep(for: .seconds(2))

            return API.Empty()
        }, downloadRelease: { _, _ in
            try await Task.sleep(for: .seconds(1))

            return API.Empty()
        }, status: { instance in
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
        }, diskSpace: { _ in
            try await Task.sleep(for: .seconds(1))

            return loadPreviewData(filename: "disk-space")
        }, tags: { _ in
            try await Task.sleep(for: .seconds(1))
            let tags: [Tag] = loadPreviewData(filename: "tags")
            return tags
        }, queue: { instance in
            try await Task.sleep(for: .seconds(1))

            let items: QueueItems = loadPreviewData(
                filename: instance.type == .sonarr ? "series-queue" : "movie-queue"
            )

            return modifyQueueItems(items, instance)
        }, deleteQueueTask: { _, _, _, _, _ in
            try await Task.sleep(for: .seconds(3))

            return API.Empty()
        }, importableFiles: { _, instance in
            try await Task.sleep(for: .seconds(1))

            let files: [ImportableFile] = loadPreviewData(
                filename: instance.type == .sonarr ? "sonarr-manual-import" : "radarr-manual-import"
            )

            return files
        }, history: { _, _, _, instance in
            try await Task.sleep(for: .seconds(2))

            let events: MediaHistory = loadPreviewData(
                filename: instance.type == .sonarr ? "sonarr-history" : "radarr-history"
            )

            return events
        }, notifications: { _ in
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

            return API.Empty()
        })
    }
}

private func loadPreviewData<Model: Decodable>(filename: String) -> Model {
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

private func modifyQueueItems(_ items: QueueItems, _ instance: Instance) -> QueueItems {
    var modifiedItems = items

    modifiedItems.records = items.records.map { record in
        var record = record

        record.stamp(instance.id)

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

        movie.stamp(instance.id)

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

        episode.stamp(instance.id)

        if let airDateUtc = item.airDateUtc {
            episode.airDateUtc = Calendar.current.date(byAdding: .day, value: Int(days), to: airDateUtc)!
        }

        return episode
    }
}
