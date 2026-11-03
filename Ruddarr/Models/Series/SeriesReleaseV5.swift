import Foundation

/// Sonarr v5's `/api/v5/release` nests what v3 returns flat, so it decodes separately and maps onto `SeriesRelease`.
struct SeriesReleaseV5: Decodable {
    let parsedInfo: ParsedInfo
    let release: Release
    let decision: Decision
    let history: SeriesReleaseHistory?

    let qualityWeight: Int
    let releaseWeight: Int
    let languages: [MediaLanguage]?
    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    let episodeRequested: Bool
    let downloadAllowed: Bool

    let mappedSeriesId: Series.ID?
    let mappedSeasonNumber: Season.ID?
    let mappedEpisodeNumbers: [Episode.ID]?
    let mappedEpisodeInfo: [SeriesReleaseEpisode]?

    struct ParsedInfo: Decodable {
        let quality: MediaQuality
        let releaseGroup: String?
        let seriesTitle: String?
        let fullSeason: Bool
        let seasonNumbers: [Season.ID]
        let episodeNumbers: [Episode.ID]?
        let special: Bool
        let isPossibleSpecialEpisode: Bool
    }

    struct Release: Decodable {
        let guid: String
        let title: String
        let size: Int
        let age: Int
        let ageMinutes: Float
        let `protocol`: ReleaseProtocol
        let indexerId: Int
        let indexer: String?
        let indexerFlags: Int?
        let seeders: Int?
        let leechers: Int?
        let infoUrl: String?
    }

    struct Decision: Decodable {
        let rejected: Bool
        let rejections: [Rejection]
    }

    struct Rejection: Decodable {
        let message: String
    }

    var seriesRelease: SeriesRelease {
        SeriesRelease(
            guid: release.guid,
            title: release.title,
            seriesTitle: parsedInfo.seriesTitle,
            size: release.size,
            age: release.age,
            ageMinutes: release.ageMinutes,
            rejected: decision.rejected,
            downloadAllowed: downloadAllowed,
            releaseGroup: parsedInfo.releaseGroup,
            customFormats: customFormats,
            customFormatScore: customFormatScore,
            network: release.protocol,
            indexerId: release.indexerId,
            indexer: release.indexer,
            indexerFlags: release.indexerFlags,
            seeders: release.seeders,
            leechers: release.leechers,
            quality: parsedInfo.quality,
            languages: languages,
            rejections: decision.rejections.map(\.message),
            qualityWeight: qualityWeight,
            releaseWeight: releaseWeight,
            infoUrl: release.infoUrl,
            history: history,
            fullSeason: parsedInfo.fullSeason,
            episodeRequested: episodeRequested,
            shouldOverride: nil,
            special: parsedInfo.special,
            isPossibleSpecialEpisode: parsedInfo.isPossibleSpecialEpisode,
            seriesId: nil,
            mappedSeriesId: mappedSeriesId,
            episodeId: nil,
            episodeIds: nil,
            seasonNumber: parsedInfo.seasonNumbers.first ?? -1,
            mappedSeasonNumber: mappedSeasonNumber,
            episodeNumbers: parsedInfo.episodeNumbers,
            mappedEpisodeNumbers: mappedEpisodeNumbers,
            mappedEpisodeInfo: mappedEpisodeInfo
        )
    }
}
