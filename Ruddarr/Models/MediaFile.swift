import Foundation

struct MediaFile: Identifiable, Equatable, Codable {
    let id: Int
    let size: Int
    let relativePath: String?
    let dateAdded: Date

    let mediaInfo: FileMediaInfo?
    let quality: MediaQuality
    let languages: [MediaLanguage]?

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int?

    // Sonarr
    let seriesId: Series.ID?
    let episodeReleaseType: EpisodeReleaseType?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        size = try container.decode(Int.self, forKey: .size)
        relativePath = try container.decodeIfPresent(String.self, forKey: .relativePath)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        mediaInfo = try container.decodeIfPresent(FileMediaInfo.self, forKey: .mediaInfo)
        quality = try container.decode(MediaQuality.self, forKey: .quality)
        customFormats = try container.decodeIfPresent([MediaCustomFormat].self, forKey: .customFormats)
        customFormatScore = try container.decodeIfPresent(Int.self, forKey: .customFormatScore)
        seriesId = try container.decodeIfPresent(Series.ID.self, forKey: .seriesId)
        episodeReleaseType = try container.decodeIfPresent(EpisodeReleaseType.self, forKey: .episodeReleaseType)

        languages = try container.decodeLossyArrayIfPresent([MediaLanguage].self, forKey: .languages)
    }

    var filenameLabel: String {
        relativePath?.components(separatedBy: "/").last?.breakable() ?? "--"
    }

    var sizeLabel: String {
        formatBytes(size, verbose: true)
    }

    var languageLabel: String {
        languageSingleLabel(languages ?? [])
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore ?? 0)
    }

    var customFormatsList: [String]? {
        guard let formats = customFormats, !formats.isEmpty else {
            return nil
        }

        return formats.map(\.label)
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

    func videoBitrateLabel(_ runtime: Int) -> String? {
        if let bitrate = mediaInfo?.videoBitrate, bitrate > 0 {
            return formatBitrate(bitrate)
        }

        let seconds = calculateRuntime(mediaInfo?.runTime) ?? (runtime * 60)

        guard let bitrate = calculateBitrate(seconds, size) else { return nil }
        guard let label = formatBitrate(bitrate) else { return nil }

        return "~\(label)"
    }
}

struct FileMediaInfo: Equatable, Codable {
    let audioBitrate: Int?
    let audioStreamCount: Int?
    let audioChannels: Float?
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

    let audioStreams: [MediaInfoAudioStream]?
    let subtitleStreams: [MediaInfoSubtitleStream]?

    var videoCodecLabel: String? {
        guard var label = videoCodec else {
            return nil
        }

        label = label.replacingOccurrences(of: "h264", with: "H.264")
        label = label.replacingOccurrences(of: "x264", with: "H.264")
        label = label.replacingOccurrences(of: "AVC", with: "H.264")

        label = label.replacingOccurrences(of: "h265", with: "H.265")
        label = label.replacingOccurrences(of: "x265", with: "H.265")
        label = label.replacingOccurrences(of: "HEVC", with: "H.265")

        label = label.replacingOccurrences(of: "h266", with: "H.266")
        label = label.replacingOccurrences(of: "x266", with: "H.266")
        label = label.replacingOccurrences(of: "VVC", with: "H.266")
        label = label.replacingOccurrences(of: "vvc", with: "H.266")

        label = label.replacingOccurrences(of: "VC1", with: "VC-1")

        return label
    }

    var videoDynamicRangeLabel: String? {
        guard let label = videoDynamicRange, !label.isEmpty else {
            return nil
        }

        if let type = videoDynamicRangeType, !type.isEmpty {
            return type
                .replacingOccurrences(of: " ", with: "/")
                .replacingOccurrences(of: "HDR10Plus", with: "HDR10+")
        }

        return label
    }

    var audioLanguageCodes: [String]? {
        guard let languages = audioLanguages, !languages.isEmpty else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }

    var subtitleCodes: [String]? {
        guard let languages = subtitles, !languages.isEmpty else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }
}

struct MediaInfoAudioStream: Equatable, Codable {
    let language: String?
    let codec: String?
    let bitrate: Int?
    let channels: Float?

    var label: String {
        Languages.name(byCode: language ?? "")
    }

    var detail: String {
        [
            codec,
            channels.map { "\($0)" },
            bitrate.flatMap { formatBitrate($0) }.map { "(\($0))" },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

struct MediaInfoSubtitleStream: Equatable, Codable {
    let language: String?
    let format: String?
    let forced: Bool?
    let hearingImpaired: Bool?

    var label: String {
        Languages.name(byCode: language ?? "")
    }

    var detail: String {
        let flags = [
            forced == true ? String(localized: "Forced") : nil,
            hearingImpaired == true ? String(localized: "SDH", comment: "Subtitles for the deaf and hard of hearing") : nil,
        ].compactMap { $0 }

        return [format, flags.isEmpty ? nil : "(\(flags.formattedList()))"]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
