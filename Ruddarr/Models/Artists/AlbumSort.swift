import SwiftUI

struct AlbumSort: Hashable {
    var isAscending: Bool = false
    var option: Option = .byReleased
    var filter: Filter = .all

    static func == (lhs: AlbumSort, rhs: AlbumSort) -> Bool {
        lhs.isAscending == rhs.isAscending &&
        lhs.option == rhs.option &&
        lhs.filter == rhs.filter
    }

    func filter(_ album: Album) -> Bool {
        return switch filter {
        case .all:
            true
        case .monitored:
            album.monitored
        case .unmonitored:
            !album.monitored
        case .missing:
            false // TODO: Come back and figure this out
        }
    }

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byName
        case byReleased
        case byRating
        case bySize

        var label: some View {
            switch self {
            case .byName: Label(String(localized: "Artist Name", comment: "Media grid sorting"), systemImage: "textformat.abc")
            case .byReleased: Label(String(localized: "Date Released", comment: "Media grid sorting"), systemImage: "calendar")
            case .byRating: Label(String(localized: "Rating", comment: "Media grid sorting"), systemImage: "star")
            case .bySize: Label(String(localized: "File Size", comment: "Media grid sorting"), systemImage: "internaldrive")
            }
        }

        func compare(_ lhs: Album, _ rhs: Album) -> Bool {
            switch self {
            case .byName:
                lhs.title < rhs.title
            case .bySize:
                lhs.sizeOnDisk < rhs.sizeOnDisk
            case .byReleased:
                lhs.releaseDate ?? Date.distantPast < rhs.releaseDate ?? Date.distantPast
            case .byRating:
                lhs.ratingScore < rhs.ratingScore
            }
        }
    }

    enum Filter: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case all
        case monitored
        case unmonitored
        case missing

        var label: some View {
            switch self {
            case .all: Label(String(localized: "All Albums", comment: "Media grid filter"), systemImage: "rectangle.stack")
            case .monitored: Label(String(localized: "Monitored", comment: "Media grid filter"), systemImage: "bookmark.fill")
            case .unmonitored: Label(String(localized: "Unmonitored", comment: "Media grid filter"), systemImage: "bookmark")
            case .missing: Label(String(localized: "Missing", comment: "Media grid filter"), systemImage: "exclamationmark.magnifyingglass")
            }
        }
    }
}
