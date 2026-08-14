import SwiftUI
import Sentry

struct BookQuery: Equatable, Sendable {
    var sortKey: String
    var sortDirection: String
    var mediaType: String
    var includeUnmonitored: Bool = false
    var monitored: Bool?
    var downloaded: Bool?
    var missing: Bool?
}

struct BookSort: Hashable {
    var isAscending: Bool = true
    var option: Option = .byTitle
    var filter: Filter = .all
    var mediaType: BookMediaType = .audiobook

    var query: BookQuery {
        var query = BookQuery(
            sortKey: option.remoteKey,
            sortDirection: isAscending ? "asc" : "desc",
            mediaType: mediaType.rawValue
        )

        switch filter {
        case .all: query.includeUnmonitored = true
        case .monitored: query.monitored = true
        case .unmonitored: query.monitored = false
        case .downloaded: query.includeUnmonitored = true; query.downloaded = true
        case .missing: query.missing = true
        }

        return query
    }

    static func == (lhs: BookSort, rhs: BookSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.filter == rhs.filter &&
        lhs.mediaType == rhs.mediaType
    }

    func filter(_ book: Book) -> Bool {
        guard mediaType.matches(book) else {
            return false
        }

        return switch filter {
        case .all:
            true
        case .monitored:
            book.monitored
        case .unmonitored:
            !book.monitored
        case .downloaded:
            book.hasFiles
        case .missing:
            book.monitored && !book.hasFiles
        }
    }

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byRelease
        case byAdded
        case bySize

        var label: some View {
            switch self {
            case .byTitle: Label(String(localized: "Title", comment: "Media grid sorting"), systemImage: "textformat.abc")
            case .byRelease: Label(String(localized: "Release Date", comment: "Media grid sorting"), systemImage: "calendar")
            case .byAdded: Label(String(localized: "Added", comment: "Media grid sorting"), systemImage: "clock")
            case .bySize: Label(String(localized: "File Size", comment: "Media grid sorting"), systemImage: "internaldrive")
            }
        }

        var remoteKey: String {
            switch self {
            case .byTitle: "title"
            case .byRelease: "releaseDate"
            case .byAdded: "added"
            case .bySize: "sizeOnDisk"
            }
        }
    }

    enum BookMediaType: String, CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case ebook
        case audiobook

        func matches(_ book: Book) -> Bool {
            book.mediaType?.caseInsensitiveCompare(rawValue) == .orderedSame
        }

        var metadataProfileType: Int {
            switch self {
            case .audiobook: 1
            case .ebook: 2
            }
        }

        func matches(_ profile: InstanceQualityProfile) -> Bool {
            guard let type = profile.profileType else { return true }
            return type.caseInsensitiveCompare(rawValue) == .orderedSame
        }

        func matches(_ profile: InstanceMetadataProfile) -> Bool {
            guard let type = profile.profileType, type != 0 else { return true }
            return type == metadataProfileType
        }

        var label: some View {
            switch self {
            case .ebook: Label(String(localized: "eBooks", comment: "Media grid format"), systemImage: "book")
            case .audiobook: Label(String(localized: "Audiobooks", comment: "Media grid format"), systemImage: "headphones")
            }
        }
    }

    enum Filter: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case all
        case monitored
        case unmonitored
        case downloaded
        case missing

        var label: some View {
            switch self {
            case .all: Label(String(localized: "All Books", comment: "Media grid filter"), systemImage: "rectangle.stack")
            case .monitored: Label(String(localized: "Monitored", comment: "Media grid filter"), systemImage: "bookmark.fill")
            case .unmonitored: Label(String(localized: "Unmonitored", comment: "Media grid filter"), systemImage: "bookmark")
            case .downloaded: Label(String(localized: "Downloaded", comment: "Media grid filter"), systemImage: "internaldrive")
            case .missing: Label(String(localized: "Missing", comment: "Media grid filter"), systemImage: "exclamationmark.magnifyingglass")
            }
        }
    }
}

extension BookSort: RawRepresentable {
    public init?(rawValue: String) {
        do {
            guard let data = rawValue.data(using: .utf8) else { return nil }
            let result = try JSONDecoder().decode(BookSort.self, from: data)
            self = result
        } catch {
            leaveBreadcrumb(.warning, category: "book.sort", message: "JSON decode failed: \(error)", data: ["error": error, "rawValue": rawValue])

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

extension BookSort: Codable {
    enum CodingKeys: String, CodingKey {
        case isAscending
        case option
        case filter
        case mediaType
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            isAscending: container.decode(Bool.self, forKey: .isAscending),
            option: container.decode(Option.self, forKey: .option),
            filter: container.decode(Filter.self, forKey: .filter),
            mediaType: container.decodeIfPresent(BookMediaType.self, forKey: .mediaType) ?? .audiobook
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isAscending, forKey: .isAscending)
        try container.encode(option, forKey: .option)
        try container.encode(filter, forKey: .filter)
        try container.encode(mediaType, forKey: .mediaType)
    }
}
