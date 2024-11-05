import SwiftUI

@Observable
class History {
    var instances: [Instance] = []

    var events: [MediaHistoryEvent] = []
    var hasMore: [Instance.ID: Bool] = [:]

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isLoading: Bool = false

    @MainActor
    func fetch(_ page: Int) async {
        error = nil
        isLoading = true

        if page == 1 {
            events.removeAll()
            hasMore.removeAll()
        }

        var results: [MediaHistoryEvent] = []

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for instance in instances {
                    if !(hasMore[instance.id] ?? true) {
                        continue
                    }

                    group.addTask {
                        let result = try await dependencies.api.fetchHistory(page, 25, instance)

                        results.append(contentsOf: result.records)
                        self.hasMore[instance.id] = result.totalRecords > result.page * result.pageSize
                    }
                }

                try await group.waitForAll()
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "history", message: "History fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        events.append(contentsOf: results)

        isLoading = false
    }
}
