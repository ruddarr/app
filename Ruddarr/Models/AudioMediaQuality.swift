import Foundation

struct AudioMediaQuality: Equatable, Codable {
    let quality: AudioMediaQualityDetails
    let revision: AudioMediaQualityRevision
}

struct AudioMediaQualityDetails: Equatable, Codable {
    let id: Int
    let name: String?

    var normalizedName: String {
        guard let label = name else {
            return String(localized: "Unknown")
        }

        if let range = label.range(of: #"-(\d+p)"#, options: .regularExpression) {
            return String(label[range].dropFirst())
        }

        return label
    }
}

struct AudioMediaQualityRevision: Equatable, Codable {
    let version: Int
    let real: Int
    let isRepack: Bool

    var isReal: Bool {
        real > 0
    }

    var isProper: Bool {
        version > 1
    }
}
