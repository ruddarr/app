import Foundation

struct SearchRequest: Equatable {
    private let id = UUID()

    let query: String
    let isDebounced: Bool
    let debounce: Duration

    init(query: String, isDebounced: Bool, debounce: Duration = .milliseconds(250)) {
        self.query = query
        self.isDebounced = isDebounced
        self.debounce = debounce
    }

    func waitForDebounce() async -> Bool {
        guard isDebounced else { return true }

        try? await Task.sleep(for: debounce)
        return !Task.isCancelled
    }
}
