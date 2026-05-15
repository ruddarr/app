import SwiftUI

enum InstanceCommand {
    case refreshMovie(_ ids: [Movie.ID])
    case search(_ ids: [Movie.ID])

    case refreshSeries(_ series: Series.ID)
    case seriesSearch(_ series: Series.ID)
    case seasonSearch(_ series: Series.ID, season: Season.ID)
    case episodeSearch(_ ids: [Episode.ID])

    case refreshArtist(_ artist: Artist.ID)
    case artistSearch(_ artist: Artist.ID)
    case albumSearch(_ artist: Artist.ID, album: Album.ID)
    case trackSearch(_ artist: Artist.ID, album: Album.ID, track: AlbumRelease.ID)

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
        case .refreshArtist(let artist):
            LidarrPayload(name: "RefreshArtist", artistId: artist)
        case .artistSearch(let artist):
            LidarrPayload(name: "ArtistSearch", artistId: artist)
        case .albumSearch(let artist, let album):
            LidarrPayload(name: "AlbumSearch", artistId: artist, albumId: album)
        case .trackSearch(let artist, let album, let track):
            LidarrPayload(name: "TrackSearch", artistId: artist, albumId: album, trackId: track)
        case .refreshDownloads:
            GenericPayload(name: "RefreshMonitoredDownloads")
        case .manualImport(let files):
            ImportPayload(files: files.map { ImportableResource.from($0) })
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

    struct LidarrPayload: Payload {
        let name: String
        let artistId: Int?
        let albumId: Int?
        let trackId: Int?

        init(name: String, artistId: Int? = nil, albumId: Int? = nil, trackId: Int? = nil) {
            self.name = name
            self.artistId = artistId
            self.albumId = albumId
            self.trackId = trackId
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

    // Lidarr
    var artistId: Int?
    var albumId: Int?

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

    init(guid: String, indexerId: Int, artistId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.artistId = artistId
    }

    init(guid: String, indexerId: Int, artistId: Int?, albumId: Int?) {
        self.guid = guid
        self.indexerId = indexerId
        self.artistId = artistId
        self.albumId = albumId
    }
}
