import Foundation

/// Identifier of a movie or series App Intents entity: `<instanceId>:<mediaId>`.
///
/// WARNING: Users' shortcuts persist these identifiers, changing the format breaks them.
struct MediaEntityID: Hashable {
    let mediaId: Int
    let instanceId: UUID

    init(_ mediaId: Int, _ instanceId: UUID) {
        self.mediaId = mediaId
        self.instanceId = instanceId
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", omittingEmptySubsequences: false)

        guard parts.count == 2,
              let instanceId = UUID(uuidString: String(parts[0])),
              let mediaId = Int(parts[1])
        else {
            return nil
        }

        self.init(mediaId, instanceId)
    }

    var rawValue: String {
        "\(instanceId.uuidString):\(mediaId)"
    }
}

/// Identifier of a movie or series Spotlight item: `<kind>:<mediaId>:<instanceId>`.
///
/// WARNING: Spotlight persists these identifiers, changing the format breaks existing items.
struct SpotlightItemID: Hashable {
    enum Kind: String {
        case movie
        case series
    }

    let kind: Kind
    let mediaId: Int
    let instance: String?

    init(_ kind: Kind, _ mediaId: Int, _ instance: String?) {
        self.kind = kind
        self.mediaId = mediaId
        self.instance = instance
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", omittingEmptySubsequences: false)

        guard parts.count == 3,
              let kind = Kind(rawValue: String(parts[0])),
              let mediaId = Int(parts[1])
        else {
            return nil
        }

        self.init(kind, mediaId, parts[2].isEmpty ? nil : String(parts[2]))
    }

    var rawValue: String {
        "\(kind.rawValue):\(mediaId):\(instance ?? "")"
    }
}
