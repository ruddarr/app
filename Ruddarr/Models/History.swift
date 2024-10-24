import SwiftUI

@Observable
class History {
    var instances: [Instance] = []

    var items: [MediaHistoryEvent] = []
    var hasMore: [Instance.ID: Bool] = [:]

    var error: API.Error?
    var isLoading: Bool = false

    @MainActor
    func fetch(_ page: Int) async {
        error = nil
        isLoading = true

        if page == 1 {
            items.removeAll()
            hasMore.removeAll()
        }
        for instance in instances {
            if !(hasMore[instance.id] ?? true) { continue }
            do {
                let result = try await dependencies.api.fetchHistory(page, instance)
                items.append(contentsOf: result.records)
                hasMore[instance.id] = result.totalRecords > result.page * result.pageSize
            } catch is CancellationError {
                // do nothing
            } catch let apiError as API.Error {
                error = apiError

                leaveBreadcrumb(.error, category: "history", message: "History fetch failed", data: ["error": apiError])
            } catch {
                self.error = API.Error(from: error)
            }
        }

        isLoading = false
    }
}
