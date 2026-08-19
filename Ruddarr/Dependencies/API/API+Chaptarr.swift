import Foundation

extension ChaptarrAPI {
    static var live: Self {
        .init(fetch: { instance in
            let url = try await instance.apiURL("book")
                .appending(queryItems: [
                    .init(name: "monitored", value: "true"),
                    .init(name: "include", value: "author,links"),
                ])

            var books: [Book] = try await API.request(url: url, instance: instance, timeout: .slow)
            books.stamp(instance.id)
            return books
        }, page: { instance, query, offset, pageSize in
            var items: [URLQueryItem] = [
                .init(name: "offset", value: String(offset)),
                .init(name: "pageSize", value: String(pageSize)),
                .init(name: "sortKey", value: query.sortKey),
                .init(name: "sortDirection", value: query.sortDirection),
                .init(name: "mediaType", value: query.mediaType),
                .init(name: "include", value: "author"),
            ]

            if query.includeUnmonitored { items.append(.init(name: "includeUnmonitored", value: "true")) }
            if let monitored = query.monitored { items.append(.init(name: "monitored", value: String(monitored))) }
            if let downloaded = query.downloaded { items.append(.init(name: "downloaded", value: String(downloaded))) }
            if let missing = query.missing { items.append(.init(name: "missing", value: String(missing))) }

            let url = try await instance.apiURL("book/paged").appending(queryItems: items)

            var page: BooksPage = try await API.request(url: url, instance: instance, timeout: .slow)
            page.records.stamp(instance.id)
            return page
        }, search: { instance, term in
            try await searchLibrary(term, instance)
        }, lookup: { instance, query in
            let url = try await instance.apiURL("book/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, book: { bookId, instance in
            let url = try await instance.apiURL("book").appending(path: String(bookId))

            var book: Book = try await API.request(url: url, instance: instance, timeout: .sluggish)
            book.stamp(instance.id)
            return book
        }, series: { authorId, instance in
            let url = try await instance.apiURL("series")
                .appending(queryItems: [.init(name: "authorId", value: String(authorId))])

            return try await API.request(url: url, instance: instance, timeout: .slow)
        }, files: { bookId, instance in
            let url = try await instance.apiURL("bookfile")
                .appending(queryItems: [.init(name: "bookId", value: String(bookId))])

            return try await API.request(url: url, instance: instance)
        }, history: { authorId, bookId, instance in
            let url = try await instance.apiURL("history/author")
                .appending(queryItems: [
                    .init(name: "authorId", value: String(authorId)),
                    .init(name: "bookId", value: String(bookId)),
                ])

            return try await API.request(url: url, instance: instance)
        }, add: { book, instance in
            let url = try await instance.apiURL("book")

            return try await API.request(method: .post, url: url, body: book, instance: instance, timeout: .sluggish)
        }, monitor: { ids, monitored, instance in
            let url = try await instance.apiURL("book/monitor")

            let body = BooksMonitorResource(bookIds: ids, monitored: monitored)

            return try await API.request(method: .put, url: url, body: body, instance: instance)
        }, deleteFile: { file, instance in
            let url = try await instance.apiURL("bookfile")
                .appending(path: String(file.id))

            return try await API.request(method: .delete, url: url, instance: instance)
        }, metadataProfiles: { instance in
            let url = try await instance.apiURL("metadataprofile")

            return try await API.request(url: url, instance: instance)
        }, calendar: { start, end, instance in
            let url = try await instance.apiURL("calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "includeAuthor", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var books: [Book] = try await API.request(url: url, instance: instance, timeout: .slow)
            books.stamp(instance.id)
            return books
        })
    }

    private static func searchLibrary(_ term: String, _ instance: Instance) async throws -> [Book] {
        let searchURL = try await instance.apiURL("library/search")
            .appending(queryItems: [
                .init(name: "term", value: term),
                .init(name: "limit", value: "50"),
            ])

        let result: BookSearchResult = try await API.request(url: searchURL, instance: instance, timeout: .slow)

        var books: [Book] = []

        if !result.books.isEmpty {
            let url = try await instance.apiURL("book")
                .appending(queryItems: result.books.map { .init(name: "bookIds", value: String($0.id)) })

            books = (try? await API.request(url: url, instance: instance, timeout: .slow)) ?? []
        }

        try Task.checkCancellation()

        let authors = result.authors.prefix(10)

        let catalogs: [Int: [Book]] = await withTaskGroup(of: (Int, [Book]).self) { group in
            for author in authors {
                group.addTask {
                    guard let url = try? await instance.apiURL("book")
                        .appending(queryItems: [.init(name: "authorId", value: String(author.id))])
                    else {
                        return (author.id, [])
                    }

                    let fetched: [Book]? = try? await API.request(url: url, instance: instance, timeout: .slow)

                    return (author.id, fetched ?? [])
                }
            }

            var catalogs: [Int: [Book]] = [:]

            for await (authorId, fetched) in group {
                catalogs[authorId] = fetched
            }

            return catalogs
        }

        try Task.checkCancellation()

        var bookIds = Set(books.map(\.id))

        for author in authors {
            books.append(contentsOf: (catalogs[author.id] ?? [])
                .filter { bookIds.insert($0.id).inserted }
                .sorted { $0.sortTitle < $1.sortTitle }
            )
        }

        let matchNames = result.books.reduce(into: [Int: String]()) { $0[$1.id] = $1.authorName }
        let authorNames = authors.reduce(into: [Int: String]()) { $0[$1.id] = $1.name }

        for index in books.indices where books[index].author == nil {
            guard let name = matchNames[books[index].id] ?? authorNames[books[index].authorId] else { continue }
            books[index].author = .init(id: books[index].authorId, authorName: name)
        }

        books.stamp(instance.id)

        return books
    }
}
