import SwiftUI
import Sentry

struct BookSearchResult: Codable, Sendable {
    let authors: [AuthorSearchMatch]
    let books: [BookSearchMatch]

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        authors = try values.decodeLossyArrayIfPresent([AuthorSearchMatch].self, forKey: .authors) ?? []
        books = try values.decodeLossyArrayIfPresent([BookSearchMatch].self, forKey: .books) ?? []
    }
}

struct BookSearchMatch: Codable, Sendable {
    let id: Int
    let authorName: String?
}

struct AuthorSearchMatch: Codable, Sendable {
    let id: Int
    let name: String?
}

struct BooksPage: Codable, Sendable {
    var records: [Book]
    let totalCount: Int

    init(records: [Book], totalCount: Int) {
        self.records = records
        self.totalCount = totalCount
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        records = try values.decodeLossyArrayIfPresent([Book].self, forKey: .records) ?? []
        totalCount = try values.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
    }
}

@MainActor
@Observable
class Books {
    var instance: Instance

    var items: [Book] = []
    var itemsCount: Int = 0

    var cachedItems: [Book] = []
    private var cachedSeries: [Int: [BookSeries]] = [:]

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false
    var isFiltering: Bool = false
    var isLoadingMore: Bool = false
    var isMonitoring: Book.ID = 0

    private var sortAndFilterTask: Task<Void, Never>?

    enum Operation {
        case fetch(BookSort)
        case add(Book)
        case command(InstanceCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func updateCachedItems(_ sort: BookSort, _ searchQuery: String) {
        sortAndFilterTask?.cancel()

        let query = searchQuery.trimmed()

        guard query.isEmpty else {
            isFiltering = true

            sortAndFilterTask = Task(priority: .userInitiated) {
                let results = (try? await dependencies.api.chaptarr.search(instance, query)) ?? []

                guard !Task.isCancelled else { return }

                cachedItems = results.filter(sort.filter)
                isFiltering = false
            }

            return
        }

        cachedItems = items
        isFiltering = false
    }

    func byId(_ id: Book.ID) -> Book? {
        items.first { $0.id == id } ?? cachedItems.first { $0.id == id }
    }

    func binding(for id: Book.ID) -> Binding<Book>? {
        guard let displayed = byId(id) else { return nil }

        return Binding(
            get: { [weak self] in
                self?.byId(id) ?? displayed
            },
            set: { [weak self] book in
                if let index = self?.items.firstIndex(where: { $0.id == id }) {
                    self?.items[index] = book
                }

                if let index = self?.cachedItems.firstIndex(where: { $0.id == id }) {
                    self?.cachedItems[index] = book
                }
            }
        )
    }

    func fetch(_ sort: BookSort) async -> Bool {
        await request(.fetch(sort))
    }

    func series(_ authorId: Int) -> [BookSeries]? {
        cachedSeries[authorId]
    }

    func fetchSeries(_ authorId: Int) async -> [BookSeries] {
        if let cached = cachedSeries[authorId] {
            return cached
        }

        guard let fetched = try? await dependencies.api.chaptarr.series(authorId, instance) else {
            return []
        }

        cachedSeries[authorId] = fetched

        return fetched
    }

    func add(_ book: Book) async -> Bool {
        await request(.add(book))
    }

    func command(_ command: InstanceCommand) async -> Bool {
        await request(.command(command))
    }

    func monitor(_ ids: [Book.ID], _ monitored: Bool) async -> Bool {
        error = nil
        isMonitoring = ids[0]

        defer { isMonitoring = 0 }

        do {
            _ = try await dependencies.api.chaptarr.monitor(ids, monitored, instance)

            for id in ids {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].monitored = monitored
                }

                if let index = cachedItems.firstIndex(where: { $0.id == id }) {
                    cachedItems[index].monitored = monitored
                }
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "books", message: "Book monitor failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }

    func request(_ operation: Operation) async -> Bool {
        error = nil
        isWorking = true

        do {
            try await performOperation(operation)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "books", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isWorking = false

        return error == nil
    }

    static let pageSize: Int = 200

    var hasMoreItems: Bool {
        items.count < itemsCount
    }

    func loadMore(_ sort: BookSort) async {
        guard !isLoadingMore, hasMoreItems, error == nil else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await dependencies.api.chaptarr.page(instance, sort.query, items.count, Self.pageSize)

            items += page.records
            itemsCount = page.totalCount
            cachedItems = items
        } catch is CancellationError {
            // do nothing
        } catch {
            leaveBreadcrumb(.error, category: "books", message: "Failed to load more", data: ["error": error])
        }
    }

    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch(let sort):
            let page = try await dependencies.api.chaptarr.page(instance, sort.query, 0, Self.pageSize)

            items = page.records
            itemsCount = page.totalCount
            cachedItems = items
            cachedSeries = [:]

            leaveBreadcrumb(.info, category: "books", message: "Fetched books", data: ["count": items.count])

        case .add(let book):
            var added = try await dependencies.api.chaptarr.add(book, instance)
            added.stamp(instance.id)

            items.append(added)
            itemsCount = items.count
            cachedSeries[added.authorId] = nil

        case .command(let command):
            _ = try await dependencies.api.instance.command(command, instance)
        }
    }

}
