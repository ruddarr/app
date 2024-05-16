import Foundation

struct MediaFile: Identifiable, Equatable, Codable {
    let id: Int
    let size: Int
    let relativePath: String?
    let dateAdded: Date

    let mediaInfo: FileMediaInfo?
    let quality: MediaQuality
    let languages: [MediaLanguage]

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    // Sonarr
    let seriesId: Series.ID?
    let releaseType: FileReleaseType?

    var sizeLabel: String {
        formatBytes(size)
    }

    var languageLabel: String {
        languageSingleLabel(languages)
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore ?? 0)
    }

    var customFormatsList: [String]? {
        guard let formats = customFormats, !formats.isEmpty else {
            return nil
        }

        return formats.map { $0.label }
    }

    var videoResolution: Int? {
        if quality.quality.resolution > 0 {
            return quality.quality.resolution
        }

        if let resolution = mediaInfo?.resolution, let range = resolution.range(of: "x") {
            return Int(resolution[range.upperBound...])
        }

        return nil
    }
}

enum FileReleaseType: String, Equatable, Codable {
    case unknown
    case singleEpisode
    case multiEpisode
    case seasonPack
}

struct FileMediaInfo: Equatable, Codable {
    let audioBitrate: Int
    let audioStreamCount: Int
    let audioChannels: Float
    let audioCodec: String?
    let audioLanguages: String?

    let videoBitDepth: Int
    let videoBitrate: Int
    let videoFps: Float
    let videoCodec: String?
    let resolution: String?
    let runTime: String?
    let videoDynamicRange: String?
    let videoDynamicRangeType: String?
    let scanType: String?

    let subtitles: String?

    var videoCodecLabel: String? {
        guard var label = videoCodec else {
            return nil
        }

        label = label.replacingOccurrences(of: "x264", with: "H264")
        label = label.replacingOccurrences(of: "h264", with: "H264")
        label = label.replacingOccurrences(of: "h265", with: "HEVC")
        label = label.replacingOccurrences(of: "x265", with: "HEVC")

        return label
    }

    var videoDynamicRangeLabel: String? {
        guard let label = videoDynamicRange, !label.isEmpty else {
            return nil
        }

        if let type = videoDynamicRangeType {
            if type == "HDR10" { return "HDR10" }
            if type == "HDR10Plus" { return "HDR10+" }
            if !type.isEmpty { return "\(label) (\(type))" }
        }

        return label
    }

    var audioLanguageCodes: [String]? {
        guard let languages = audioLanguages, languages.count > 0 else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }

    var subtitleCodes: [String]? {
        guard let languages = subtitles, languages.count > 0 else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }
}
