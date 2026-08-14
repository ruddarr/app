import SwiftUI

struct BookSeries: Identifiable, Equatable, Codable {
    let id: Int
    let title: String
    let books: [BookSeriesBook]

    var widestPosition: String {
        func weight(_ label: String) -> (Int, Int) {
            (label.filter(\.isNumber).count, label.count)
        }

        return books.map(\.positionLabel).max { weight($0) < weight($1) } ?? ""
    }

    var sortedBooks: [BookSeriesBook] {
        books.sorted {
            let left = $0.releaseDate ?? .distantFuture
            let right = $1.releaseDate ?? .distantFuture

            if left != right {
                return left < right
            }

            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    var bookKeys: Set<String> {
        Set(books.compactMap(\.libraryKey))
    }

    func lists(_ key: String) -> Bool {
        books.contains { $0.foreignBookId == key }
    }
}

struct BookSeriesBook: Equatable, Codable {
    let title: String
    let position: String
    let foreignBookId: String?
    let releaseDate: Date?

    var positionLabel: String {
        position.isEmpty ? "#" : position
    }

    var libraryKey: String? {
        guard let id = foreignBookId, !id.isEmpty else { return nil }
        return id
    }
}
