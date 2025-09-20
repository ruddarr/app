import SwiftUI
import CoreSpotlight

protocol Media: Identifiable, Sendable where ID: Sendable {
    var title: String { get }
    var remotePoster: String? { get }

    var searchableHash: String { get }
    func searchableItem(poster: URL?) -> CSSearchableItem
}

struct Tag: Identifiable, Equatable, Codable {
    let id: Int
    var label: String
}

struct MediaLanguage: Equatable, Codable {
    let id: Int
    let name: String?

    var label: String {
        guard let name else {
            return String(localized: "Unknown")
        }

        let english = Locale(identifier: "en")

        let code = Locale.LanguageCode.isoLanguageCodes.first(where: {
            guard let language = english.localizedString(forLanguageCode: $0.identifier) else { return false }
            return language.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        })

        guard let code, let label = Locale.current.localizedString(forLanguageCode: code.identifier) else {
            return String(localized: "Unknown")
        }

        return label
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

enum ReleaseProtocol: String, Codable {
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
    var label: String
    var value: String

    init(_ label: String, value: String) {
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

func mediaDetailsSubtitles(_ file: MediaFile?, _ deviceType: DeviceType) -> String? {
    guard let codes = file?.mediaInfo?.subtitleCodes else {
        return nil
    }

    let limit = deviceType == .phone ? 2 : 5

    if codes.count > limit {
        var someCodes = Array(codes.prefix(limit)).map {
            $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
        }

        someCodes.append(
            String(localized: "+\(codes.count - limit) more...")
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

    #if os(iOS)
        private var screenWidth: CGFloat {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .screen.bounds.width ?? 0
        }
    #endif

    func body(content: Content) -> some View {
        #if os(iOS)
            if deviceType == .phone {
                content.frame(width: screenWidth * 0.4)
            } else {
                content.frame(width: 200, height: 300)
            }
        #else
            content.frame(width: 200, height: 300)
        #endif
    }
}
