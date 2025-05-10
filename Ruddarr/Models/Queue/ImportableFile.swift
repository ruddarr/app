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

    static func from(_ file: ImportableFile) -> Self {
        .init(
            path: file.path ?? "",
            downloadId: file.downloadId ?? "",
            quality: file.quality,
            languages: file.languages,
            releaseGroup: file.releaseGroup,
            movieId: file.movie == nil ? nil : file.movie?.id,
            seriesId: file.series == nil ? nil : file.series?.id,
            episodeIds: file.series == nil ? nil : file.episodes?.map(\.id),
            releaseType: file.releaseType
        )
    }
}

extension Array where Element == ImportableFile {
    func acceptable() -> [ImportableFile] {
        self.filter {
            $0.rejections.contains {
                $0.reason?.caseInsensitiveCompare("sample") != .orderedSame
            }
        }
    }
}
