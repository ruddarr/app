import SwiftUI

@MainActor
@Observable
class MovieMetadata {
    private var movieId: Movie.ID?

    var instance: Instance

    var files: [MediaFile] = []
    var extraFiles: [MovieExtraFile] = []
    var history: [MediaHistoryEvent] = []

    var filesLoading: Bool = false
    var filesError: Bool = false

    var historyLoading: Bool = false
    var historyError: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func setMovie(_ movie: Movie) {
        guard movieId == movie.id else {
            return
        }

        files = []
        extraFiles = []
        filesLoading = false

        history = []
        historyLoading = false
    }

    func fetchFiles(for movie: Movie) async {
        if movieId == movie.id && !files.isEmpty {
            return
        }

        filesLoading = true
        filesError = false

        do {
            files = try await dependencies.api.getMovieFiles(movie.id, instance)
            extraFiles = try await dependencies.api.getMovieExtraFiles(movie.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            filesError = true
        }

        filesLoading = false
    }

    func fetchHistory(for movie: Movie) async {
        if movieId == movie.id && !history.isEmpty {
            return
        }

        historyLoading = true
        historyError = false

        do {
            history = try await dependencies.api.getMovieHistory(movie.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            historyError = true
        }

        historyLoading = false
    }

    func refresh(for movie: Movie) async {
        do {
            files = try await dependencies.api.getMovieFiles(movie.id, instance)
            extraFiles = try await dependencies.api.getMovieExtraFiles(movie.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            filesError = true
        }

        filesLoading = false

        do {
            history = try await dependencies.api.getMovieHistory(movie.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch {
            historyError = true
        }

        historyLoading = false
    }

    func delete(_ file: MediaFile) async -> Bool {
        do {
            _ = try await dependencies.api.deleteMovieFile(file, instance)

            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files.remove(at: index)
            }

            return true
        } catch is CancellationError {
            // do nothing
        } catch {
            leaveBreadcrumb(.error, category: "movie.metadata", message: "Failed to delete file", data: ["error": error])
        }

        return false
    }
}

struct MovieExtraFile: Identifiable, Codable {
    let id: Int
    let type: MovieExtraFileType
    let relativePath: String?

    enum MovieExtraFileType: String, Codable {
        case subtitle
        case metadata
        case other

        var label: String {
            switch self {
            case .subtitle: String(localized: "Subtitles", comment: "Type of the extra movie file")
            case .metadata: String(localized: "Metadata", comment: "Type of the extra movie file")
            case .other: String(localized: "Other", comment: "Type of the extra movie file")
            }
        }
    }
}
