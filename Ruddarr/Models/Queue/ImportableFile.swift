import Foundation

struct ImportableFile: Identifiable, Codable {
    let id: Int

    let name: String?
    let path: String?
    let relativePath: String?
    let size: Int
    let quality: MediaQuality
    let languages: [MediaLanguage]?
    let releaseGroup: String?
    let downloadId: String?

    let rejections: [ImportableFileRejection]

    // radarr
    let movie: Movie?

    // sonarr
    let series: Series?
    let episodes: [Episode]?
    let releaseType: EpisodeReleaseType?

    var qualityLabel: String {
        quality.quality.label
    }

    var sizeLabel: String {
        formatBytes(size)
    }

    var languageLabel: String {
        languageSingleLabel(languages ?? [])
    }

    var reasons: [String] {
        rejections
            .filter { $0.reason != nil }
            .map(\.reason!)
    }

    func toResource() -> ImportableResource {
        .init(
            path: path ?? "",
            downloadId: downloadId ?? "",
            quality: quality,
            languages: languages,
            releaseGroup: releaseGroup,
            movieId: movie == nil ? nil : movie?.id,
            seriesId: series == nil ? nil : series?.id,
            episodeIds: series == nil ? nil : episodes?.map(\.id),
            releaseType: releaseType
        )
    }
}

struct ImportableFileRejection: Codable {
    let reason: String?
}

struct ImportableResource: Codable {
    let path: String
    let downloadId: String
    let quality: MediaQuality
    let languages: [MediaLanguage]?
    let releaseGroup: String?

    // radarr
    let movieId: Int?

    // sonarr
    let seriesId: Int?
    let episodeIds: [Int]?
    let releaseType: EpisodeReleaseType?
}
