import Foundation

struct SearchRequest: Equatable {
    private let id = UUID()

    let query: String
    let isDebounced: Bool

    init(query: String, isDebounced: Bool) {
        self.query = query
        self.isDebounced = isDebounced
    }

    func waitForDebounce() async -> Bool {
        guard isDebounced else { return true }

        try? await Task.sleep(for: .milliseconds(250))
        return !Task.isCancelled
    }
}
