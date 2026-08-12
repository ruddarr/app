import SwiftUI
import Sentry

@MainActor
@Observable
class SeriesFiles {
    var instance: Instance

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func delete(_ file: MediaFile) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteEpisodeFile(file, instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.files", message: "Episode deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }

    func delete(_ files: [MediaFile]) async -> Bool {
        error = nil

        do {
            _ = try await dependencies.api.deleteEpisodeFiles(files, instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.files", message: "Episode deletion failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        return error == nil
    }
}
