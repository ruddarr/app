import Foundation

struct ImportableFile: Identifiable, Codable {
    let id: Int

    let relativePath: String?
    let size: Int
    let quality: MediaQuality
    let languages: [MediaLanguage]?

    let rejections: [ImportableFileRejection]

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
