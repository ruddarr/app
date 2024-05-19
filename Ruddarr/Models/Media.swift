import SwiftUI

struct MediaLanguage: Equatable, Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MediaAlternateTitle: Equatable, Codable {
    let title: String
}

struct MediaCustomFormat: Identifiable, Equatable, Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

enum MediaReleaseType: String, Codable {
    case usenet
    case torrent
    case unknown

    var label: String {
        switch self {
        case .usenet: String(localized: "Usenet")
        case .torrent: String(localized: "Torrent")
        case .unknown: String(localized: "Unknown")
        }
    }
}

struct MediaImage: Equatable, Codable {
    let coverType: String
    let remoteURL: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case coverType
        case remoteURL = "remoteUrl"
        case url
    }
}

func languageSingleLabel(_ languages: [MediaLanguage]) -> String {
    if languages.isEmpty {
        return String(localized: "Unknown")
    }

    if languages.count == 1 {
        return languages[0].label

    }

    return String(localized: "Multilingual")
}

struct MediaDetailsRow: View {
    var label: LocalizedStringKey
    var value: String

    init(_ label: LocalizedStringKey, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        GridRow(alignment: .top) {
            Text(label)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .padding(.trailing)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }
}

func mediaDetailsVideoQuality(_ file: MediaFile?) -> String {
    var quality = ""
    var details: [String] = []

    if let resolution = file?.videoResolution {
        quality = "\(resolution)p"
        quality = quality.replacingOccurrences(of: "2160p", with: "4K")
        quality = quality.replacingOccurrences(of: "4320p", with: "8K")

        if let dynamicRange = file?.mediaInfo?.videoDynamicRangeLabel {
            quality += " \(dynamicRange)"
        }
    }

    if quality.isEmpty {
        quality = String(localized: "Unknown")
    }

    if let codec = file?.mediaInfo?.videoCodecLabel {
        details.append(codec)
    }

    if details.isEmpty {
        return quality
    }

    return "\(quality) (\(details.formattedList()))"
}

func mediaDetailsAudioQuality(_ file: MediaFile?) -> String {
    var languages: [String] = []
    var codec = ""

    if let langs = file?.languages {
        languages = langs
            .filter { $0.name != nil }
            .map { $0.label }
    }

    if let audioCodec = file?.mediaInfo?.audioCodec {
        codec = audioCodec

        if let channels = file?.mediaInfo?.audioChannels {
            codec += " \(channels)"
        }
    }

    if languages.isEmpty {
        languages.append(String(localized: "Unknown"))
    }

    let languageList = languages.count > 2
        ? String(localized: "Multilingual")
        : languages.formattedList()

    return codec.isEmpty ? "\(languageList)" : "\(languageList) (\(codec))"
}

func mediaDetailsSubtitles(_ file: MediaFile?) -> String? {
    guard let codes = file?.mediaInfo?.subtitleCodes else {
        return nil
    }

    if codes.count > 2 {
        var someCodes = Array(codes.prefix(2)).map {
            $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
        }

        someCodes.append(
            String(format: String(localized: "+%d more..."), codes.count - 2)
        )

        return someCodes.formattedList()
    }

    return languagesList(codes)
}

struct MediaPreviewActionModifier: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    func body(content: Content) -> some View {
        if deviceType == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: 215)
        }
    }
}

struct MediaPreviewActionSpacerModifier: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    func body(content: Content) -> some View {
        if deviceType == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

struct MediaDetailsPosterModifier: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    func body(content: Content) -> some View {
        if deviceType == .phone {
            content.containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 0)
        } else {
            content.frame(width: 200, height: 300)
        }
    }
}
