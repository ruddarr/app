import Sentry

@MainActor
@Observable
class BookMetadata {
    private var bookId: Book.ID?

    var instance: Instance

    var files: [BookFile] = []
    var history: [MediaHistoryEvent] = []

    var filesLoading: Bool = false
    var filesError: Bool = false

    var historyLoading: Bool = false
    var historyError: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func setBook(_ book: Book) {
        guard bookId != book.id else {
            return
        }

        bookId = book.id

        files = []
        filesLoading = false

        history = []
        historyLoading = false
    }

    func fetchFiles(for book: Book) async {
        if bookId == book.id && !files.isEmpty {
            return
        }

        filesLoading = true
        filesError = false

        do {
            files = try await dependencies.api.chaptarr.files(book.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            filesError = true
        }

        filesLoading = false
    }

    func fetchHistory(for book: Book) async {
        if bookId == book.id && !history.isEmpty {
            return
        }

        historyLoading = true
        historyError = false

        do {
            history = try await dependencies.api.chaptarr.history(book.authorId, book.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            historyError = true
        }

        historyLoading = false
    }

    func refresh(for book: Book) async {
        filesError = false
        historyError = false

        do {
            files = try await dependencies.api.chaptarr.files(book.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            filesError = true
        }

        filesLoading = false

        do {
            history = try await dependencies.api.chaptarr.history(book.authorId, book.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            historyError = true
        }

        historyLoading = false
    }

    func delete(_ file: BookFile) async -> Bool {
        do {
            _ = try await dependencies.api.chaptarr.deleteFile(file, instance)

            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files.remove(at: index)
            }

            return true
        } catch is CancellationError {
            // do nothing
        } catch {
            leaveBreadcrumb(.error, category: "book.metadata", message: "Failed to delete file", data: ["error": error])
        }

        return false
    }
}
