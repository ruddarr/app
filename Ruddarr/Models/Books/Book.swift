import SwiftUI

struct Book: Identifiable, Equatable, Codable {
    var id: Int { guid ?? foreignId }

    private(set) var guid: Int?

    private(set) var instanceId: Instance.ID?

    let foreignBookId: String?
    let foreignEditionId: String?
    let titleSlug: String?

    let title: String
    let authorTitle: String?
    let seriesTitle: String?
    let disambiguation: String?
    private(set) var overview: String?
    let narrator: String?
    let mediaType: String?

    let authorId: Int
    var author: BookAuthor?

    var monitored: Bool
    var audiobookMonitored: Bool
    var anyEditionOk: Bool
    var addOptions: BookAddOptions?
    var editions: [BookEdition]?

    let hasFiles: Bool
    let pageCount: Int
    let durationMinutes: Double?

    let genres: [String]
    let ratings: BookRatings?
    let releaseDate: Date?
    let added: Date?
    let images: [MediaImage]
    let links: [BookLink]
    let statistics: BookStatistics?

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case foreignBookId
        case foreignEditionId
        case titleSlug
        case title
        case authorTitle
        case seriesTitle
        case disambiguation
        case overview
        case narrator
        case mediaType
        case authorId
        case author
        case monitored
        case audiobookMonitored
        case anyEditionOk
        case addOptions
        case editions
        case hasFiles
        case pageCount
        case durationMinutes
        case genres
        case ratings
        case releaseDate
        case added
        case images
        case links
        case statistics
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        guid = try values.decodeIfPresent(Int.self, forKey: .guid)
        foreignBookId = try values.decodeIfPresent(String.self, forKey: .foreignBookId)
        foreignEditionId = try values.decodeIfPresent(String.self, forKey: .foreignEditionId)
        titleSlug = try values.decodeIfPresent(String.self, forKey: .titleSlug)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        authorTitle = try values.decodeIfPresent(String.self, forKey: .authorTitle)
        seriesTitle = try values.decodeIfPresent(String.self, forKey: .seriesTitle)
        disambiguation = try values.decodeIfPresent(String.self, forKey: .disambiguation)
        overview = try values.decodeIfPresent(String.self, forKey: .overview)
        narrator = try values.decodeIfPresent(String.self, forKey: .narrator)
        mediaType = try values.decodeIfPresent(String.self, forKey: .mediaType)
        authorId = try values.decodeIfPresent(Int.self, forKey: .authorId) ?? 0
        author = try? values.decodeIfPresent(BookAuthor.self, forKey: .author)
        monitored = try values.decodeIfPresent(Bool.self, forKey: .monitored) ?? false
        audiobookMonitored = try values.decodeIfPresent(Bool.self, forKey: .audiobookMonitored) ?? false
        anyEditionOk = try values.decodeIfPresent(Bool.self, forKey: .anyEditionOk) ?? true
        addOptions = try? values.decodeIfPresent(BookAddOptions.self, forKey: .addOptions)
        editions = try values.decodeLossyArrayIfPresent([BookEdition].self, forKey: .editions)
        hasFiles = try values.decodeIfPresent(Bool.self, forKey: .hasFiles) ?? false
        pageCount = try values.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        durationMinutes = try values.decodeIfPresent(Double.self, forKey: .durationMinutes)
        genres = try values.decodeLossyArrayIfPresent([String].self, forKey: .genres) ?? []
        ratings = try? values.decodeIfPresent(BookRatings.self, forKey: .ratings)
        releaseDate = try? values.decodeIfPresent(Date.self, forKey: .releaseDate)
        added = try? values.decodeIfPresent(Date.self, forKey: .added)
        images = try values.decodeLossyArrayIfPresent([MediaImage].self, forKey: .images) ?? []
        links = try values.decodeLossyArrayIfPresent([BookLink].self, forKey: .links) ?? []
        statistics = try? values.decodeIfPresent(BookStatistics.self, forKey: .statistics)
    }

    mutating func attach(overview: String?) {
        guard let overview, !overview.isEmpty else { return }
        self.overview = overview
    }

    var exists: Bool {
        guid != nil
    }

    var foreignId: Int {
        guard let suffix = foreignBookId?.split(separator: ":").last, let id = Int(suffix) else { return 0 }
        return isAudiobook ? id : -id
    }

    var webLinks: [BookLink] {
        ["hardcover", "goodreads"].compactMap { name in
            links.first {
                $0.name?.caseInsensitiveCompare(name) == .orderedSame && $0.destination != nil
            }
        }
    }

    var rootFolderPath: String? {
        let mediaTypePath = isAudiobook
            ? author?.audiobookRootFolderPath
            : author?.ebookRootFolderPath

        guard let path = (mediaTypePath ?? author?.rootFolderPath)?.trimmed(), !path.isEmpty else {
            return nil
        }

        return path
    }

    var authorLabel: String? {
        guard let name = author?.authorName, !name.isEmpty else { return nil }
        return name
    }

    var searchableAuthor: String? {
        authorLabel ?? authorTitle
    }

    var sortTitle: String {
        title.lowercased()
    }

    var sortAuthor: String {
        (author?.sortNameLastFirst ?? author?.sortName ?? authorTitle ?? title).lowercased()
    }

    var sortReleaseDate: TimeInterval {
        releaseDate?.timeIntervalSince1970
            ?? Date.distantFuture.timeIntervalSince1970
    }

    var sortAdded: TimeInterval {
        added?.timeIntervalSince1970
            ?? Date.distantPast.timeIntervalSince1970
    }

    var year: Int? {
        guard let releaseDate else { return nil }
        return Calendar.current.component(.year, from: releaseDate)
    }

    var yearLabel: String {
        year.map(String.init)
            ?? String(localized: "TBA", comment: "(Short, 3-6 characters) Conveying unannounced")
    }

    var pageCountLabel: String? {
        guard pageCount > 0 else { return nil }
        return String(localized: "\(pageCount) Page", comment: "Number of pages in a book")
    }

    var durationLabel: String? {
        guard let minutes = durationMinutes, minutes > 0 else { return nil }
        return formatRuntime(Int(minutes.rounded()))
    }

    var sizeOnDisk: Int? {
        statistics?.sizeOnDisk
    }

    var sizeLabel: String? {
        guard let bytes = sizeOnDisk, bytes > 0 else { return nil }
        return formatBytes(bytes)
    }

    var genreLabel: String {
        Array(genres.prefix(3)).formattedList()
    }

    var ratingScore: Float {
        ratings?.value ?? 0
    }

    var remotePoster: String? {
        let covers = ["cover", "poster"]

        for coverType in covers {
            if let image = images.first(where: { $0.coverType == coverType }) {
                return image.remoteURL
            }
        }

        return images.first?.remoteURL
    }

    var isAudiobook: Bool {
        mediaType?.caseInsensitiveCompare("audiobook") == .orderedSame
    }

    var posterAspect: CGSize {
        isAudiobook
            ? CGSize(width: 150, height: 150)
            : CGSize(width: 150, height: 225)
    }

    var posterHeightRatio: CGFloat {
        isAudiobook ? 1 : 1.5
    }

    var isWaiting: Bool {
        guard let releaseDate else { return true }
        return releaseDate.timeIntervalSinceNow > 0
    }

    var stateLabel: String {
        if hasFiles {
            return String(localized: "Downloaded", comment: "State of media item")
        }

        if monitored {
            return String(localized: "Missing", comment: "State of media item")
        }

        return String(localized: "Unwanted", comment: "State of media item")
    }
}

struct BookLink: Equatable, Hashable, Codable {
    let url: String?
    let name: String?

    var destination: URL? {
        url.flatMap { URL(string: $0) }
    }

    var label: String? {
        switch name?.lowercased() {
        case "hardcover": "Hardcover"
        case "goodreads": "Goodreads"
        default: nil
        }
    }
}

struct BooksMonitorResource: Codable {
    let bookIds: [Int]
    let monitored: Bool
}

struct BookAuthor: Identifiable, Equatable, Codable {
    let id: Int?
    let authorName: String?
    let sortName: String?
    let sortNameLastFirst: String?
    let rootFolderPath: String?
    var audiobookRootFolderPath: String?
    let ebookRootFolderPath: String?

    var foreignAuthorId: String?
    var monitored: Bool?
    var audiobookQualityProfileId: Int?
    var audiobookMetadataProfileId: Int?
    var audiobookMonitorExisting: Int?
    var audiobookMonitorFuture: Bool?
    var tags: [Int]?
    var audiobookTags: [Int]?
}

struct BookAddOptions: Equatable, Codable {
    var addType: String?
    var searchForNewBook: Bool?
}

struct BookEdition: Equatable, Codable {
    let bookId: Int?
    let foreignEditionId: String?
    let titleSlug: String?
    let title: String?
    let isEbook: Bool?
    let manualAdd: Bool?
    var monitored: Bool?
}

struct BookRatings: Equatable, Codable {
    let votes: Int?
    let value: Float?
}

struct BookStatistics: Equatable, Codable {
    let bookFileCount: Int?
    let bookCount: Int?
    let sizeOnDisk: Int?
}

extension Book: InstanceScoped {
    mutating func stamp(_ instance: Instance.ID?) {
        instanceId = instance
    }
}

extension Book {
    var audiobookRootFolderPath: String {
        get { author?.audiobookRootFolderPath ?? "" }
        set { author?.audiobookRootFolderPath = newValue }
    }

    var audiobookQualityProfileId: Int {
        get { author?.audiobookQualityProfileId ?? 0 }
        set { author?.audiobookQualityProfileId = newValue }
    }

    var audiobookMetadataProfileId: Int {
        get { author?.audiobookMetadataProfileId ?? 0 }
        set { author?.audiobookMetadataProfileId = newValue }
    }

    var audiobookMonitorFuture: Bool {
        get { author?.audiobookMonitorFuture ?? false }
        set { author?.audiobookMonitorFuture = newValue }
    }

    var authorTags: [Int] {
        get { author?.audiobookTags ?? [] }
        set {
            author?.tags = newValue
            author?.audiobookTags = newValue
        }
    }

    mutating func prepareForAdd(searchForNewBook: Bool) {
        monitored = true
        audiobookMonitored = true
        anyEditionOk = true

        addOptions = BookAddOptions(
            addType: "manual",
            searchForNewBook: searchForNewBook
        )

        if var editions, !editions.isEmpty {
            for index in editions.indices {
                editions[index].monitored = index == 0
            }

            self.editions = editions
        }

        author?.monitored = true

        author?.audiobookMonitorExisting = 0
    }
}
