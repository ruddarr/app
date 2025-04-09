import SwiftUI

@MainActor
@Observable
class History {
    var instances: [Instance] = []

    var events: [MediaHistoryEvent] = []
    var fetchedType: String?
    var hasMore: [Instance.ID: Bool] = [:]

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isLoading: Bool = false

    func fetch(_ page: Int, _ type: String?) async {
        error = nil
        isLoading = true

        var results: [MediaHistoryEvent] = []

        if page == 1 || type != fetchedType {
            events.removeAll()
            hasMore.removeAll()
        }

        fetchedType = type

        do {
            try await withThrowingTaskGroup(of: (Instance, MediaHistory).self) { group in
                for instance in instances {
                    if hasMore[instance.id] == false {
                        continue
                    }

                    let eventType: Int? = eventType(type, for: instance)

                    group.addTask {(
                        instance,
                        try await dependencies.api.fetchHistory(eventType, page, 25, instance)
                    )}
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

        events.append(contentsOf: results)

        isLoading = false
    }

    // swiftlint:disable:next cyclomatic_complexity
    func eventType(_ type: String?, for instance: Instance) -> Int? {
        if instance.type == .radarr {
            return switch type {
            case ".grabbed": 1
            case ".imported": 3
            case ".failed": 4
            case ".deleted": 6
            case ".renamed": 8
            case ".ignored": 9
            default: nil
            }
        }

        if instance.type == .sonarr {
            return switch type {
            case ".grabbed": 1
            case ".imported": 3
            case ".failed": 4
            case ".deleted": 5
            case ".renamed": 6
            case ".ignored": 7
            default: nil
            }
        }

        return nil
    }
}
