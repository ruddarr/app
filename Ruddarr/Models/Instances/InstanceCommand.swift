import SwiftUI

enum InstanceCommand {
    case refreshMovie(_ ids: [Movie.ID])
    case search(_ ids: [Movie.ID])

    case refreshSeries(_ series: Series.ID)
    case seriesSearch(_ series: Series.ID)
    case seasonSearch(_ series: Series.ID, season: Season.ID)
    case episodeSearch(_ ids: [Episode.ID])

    case refreshDownloads

    case manualImport(_ files: [ImportableFile])

    var payload: any Payload {
        switch self {
        case .refreshMovie(let ids):
            RadarrPayload(name: "RefreshMovie", movieIds: ids)
        case .search(let ids):
            RadarrPayload(name: "MoviesSearch", movieIds: ids)
        case .refreshSeries(let series):
            SonarrPayload(name: "RefreshSeries", seriesId: series)
        case .seriesSearch(let series):
            SonarrPayload(name: "SeriesSearch", seriesId: series)
        case .seasonSearch(let series, let season):
            SonarrPayload(name: "SeasonSearch", seriesId: series, seasonNumber: season)
        case .episodeSearch(let ids):
            SonarrPayload(name: "EpisodeSearch", episodeIds: ids)
        case .refreshDownloads:
            GenericPayload(name: "RefreshMonitoredDownloads")
        case .manualImport(let files):
            ImportPayload(files: files.map { $0.toResource() })
        }
    }

    protocol Payload: Encodable {
        var name: String { get }
    }

    struct GenericPayload: Payload {
        let name: String
    }

    struct RadarrPayload: Payload {
        let name: String
        let movieIds: [Int]?

        init(name: String, movieIds: [Int]? = nil) {
            self.name = name
            self.movieIds = movieIds
        }
    }

    struct SonarrPayload: Payload {
        let name: String
        let seriesId: Int?
        let seasonNumber: Int?
        let episodeIds: [Int]?

        init(name: String, seriesId: Int? = nil, seasonNumber: Int? = nil, episodeIds: [Int]? = nil) {
            self.name = name
            self.seriesId = seriesId
            self.seasonNumber = seasonNumber
            self.episodeIds = episodeIds
        }
    }

    struct ImportPayload: Payload {
        let name: String = "ManualImport"
        let files: [ImportableResource]
        let importMode: String = "auto"
    }
}

struct DownloadReleaseCommand: Codable {
    let guid: String
    let indexerId: Int

    // Radarr
    var movieId: Int?

    // Sonarr (season)
    var seriesId: Int?
    var seasonNumber: Int?

    // Sonarr (episode)
    var episodeId: Int?

    init(guid: String, indexerId: Int, movieId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.movieId = movieId
    }

    init(guid: String, indexerId: Int, seriesId: Int?, seasonId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.seriesId = seriesId
        self.seasonNumber = seasonId
    }

    init(guid: String, indexerId: Int, episodeId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.episodeId = episodeId
    }
}
