import Foundation

struct BookFile: Identifiable, Equatable, Codable {
    let id: Int
    let bookId: Int?
    let size: Int
    let path: String?
    let dateAdded: Date

    let quality: MediaQuality
    let mediaInfo: BookMediaInfo?
    let mediaType: String?
    let narrator: String?

    var filenameLabel: String {
        path?.components(separatedBy: "/").last?.breakable() ?? "--"
    }

    var sizeLabel: String {
        formatBytes(size, verbose: true)
    }

    var audioLabel: String? {
        let parts = [mediaInfo?.audioCodec, mediaInfo?.audioBitRate]
            .compactMap { $0?.trimmed() }
            .filter { !$0.isEmpty }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

struct BookMediaInfo: Equatable, Codable {
    let audioChannels: Float?
    let audioBitRate: String?
    let audioCodec: String?
    let audioBits: String?
    let audioSampleRate: String?

    var hasAudio: Bool {
        if audioChannels != nil {
            return true
        }

        return [audioBitRate, audioCodec, audioBits, audioSampleRate]
            .contains { !($0?.trimmed().isEmpty ?? true) }
    }
}
