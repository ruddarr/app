import SwiftUI

@MainActor
@Observable
class History {
    var instances: [Instance] = []

    var events: [MediaHistoryEvent] = []
    var hasMore: [Instance.ID: Bool] = [:]

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isLoading: Bool = false

    func fetch(_ page: Int) async {
        error = nil
        isLoading = true

        var results: [MediaHistoryEvent] = []

        do {
            try await withThrowingTaskGroup(of: (Instance, MediaHistory).self) { group in
                for instance in instances {
                    if hasMore[instance.id] == false {
                        continue
                    }

                    group.addTask {
                        (instance, try await dependencies.api.fetchHistory(page, 25, instance))
                    }
                }

                for try await (instance, history) in group {
                    results.append(contentsOf: history.records)
                    hasMore[instance.id] = history.totalRecords > history.page * history.pageSize
                }
            }
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "history", message: "History fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        if page == 1 {
            events.removeAll()
            hasMore.removeAll()
        }

        events.append(contentsOf: results)

        isLoading = false
    }
}
