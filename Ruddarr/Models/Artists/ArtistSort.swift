import SwiftUI

struct ArtistSort: Hashable {
    var isAscending: Bool = false
    var option: Option = .byAdded
    var filter: Filter = .all
    var folder: String = .all

    static func == (lhs: ArtistSort, rhs: ArtistSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.filter == rhs.filter &&
        lhs.folder == rhs.folder
    }

    func filter(_ artist: Artist) -> Bool {
        if folder != .all && artist.rootFolderPath != folder {
            return false
        }

        return switch filter {
        case .all:
            true
        case .monitored:
            artist.monitored
        case .unmonitored:
            !artist.monitored
        case .ended:
            artist.ended
        case .continuing:
            !artist.ended
        case .missing:
            artist.monitored && artist.percentOfTracks != 100
        }
    }

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byName
        case byAdded
        case byRating
        case bySize

        var label: some View {
            switch self {
            case .byName: Label(String(localized: "Artist Name", comment: "Media grid sorting"), systemImage: "textformat.abc")
            case .byAdded: Label(String(localized: "Added", comment: "Media grid sorting"), systemImage: "calendar.badge.plus")
            case .byRating: Label(String(localized: "Rating", comment: "Media grid sorting"), systemImage: "star")
            case .bySize: Label(String(localized: "File Size", comment: "Media grid sorting"), systemImage: "internaldrive")
            }
        }

        func compare(_ lhs: Artist, _ rhs: Artist) -> Bool {
            switch self {
            case .byName:
                lhs.sortName ?? "" < rhs.sortName ?? ""
            case .bySize:
                lhs.sizeOnDisk < rhs.sizeOnDisk
            case .byAdded:
                lhs.added < rhs.added
            case .byRating:
                lhs.ratings?.value ?? 0 < rhs.ratings?.value ?? 0
            }
        }
    }

    enum Filter: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case all
        case monitored
        case unmonitored
        case missing
        case continuing
        case ended

        var label: some View {
            switch self {
            case .all: Label(String(localized: "All Artists", comment: "Media grid filter"), systemImage: "rectangle.stack")
            case .monitored: Label(String(localized: "Monitored", comment: "Media grid filter"), systemImage: "bookmark.fill")
            case .unmonitored: Label(String(localized: "Unmonitored", comment: "Media grid filter"), systemImage: "bookmark")
            case .continuing: Label(String(localized: "Continuing", comment: "Media grid filter"), systemImage: "play.fill")
            case .ended: Label(String(localized: "Ended", comment: "Media grid filter"), systemImage: "stop.fill")
            case .missing: Label(String(localized: "Missing", comment: "Media grid filter"), systemImage: "exclamationmark.magnifyingglass")
            }
        }
    }
}

extension ArtistSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(ArtistSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.fatal, category: "artist.sort", message: "JSON decode failed: \(error)", data: ["error": error])

            return nil
        }
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return result
    }
}

extension ArtistSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case filter
        case folder
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            filter: container.decode(Filter.self, forKey: .filter),
            folder: container.decode(String.self, forKey: .folder)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(filter, forKey: .filter)
        try container.encode(folder, forKey: .folder)
    }
}
