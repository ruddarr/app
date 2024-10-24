import SwiftUI

struct QueueSort: Equatable {
    var isAscending: Bool = false
    var option: Option = .byAdded

    var instance: String = ".all"
    var type: String = ".all"
    var client: String = ".all"

    var issues: Bool = false

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byAdded

        var label: some View {
            switch self {
            case .byTitle: Label("Title", systemImage: "textformat.abc")
            case .byAdded: Label("Added", systemImage: "calendar.badge.plus")
            }
        }

        func isOrderedBefore(_ lhs: QueueItem, _ rhs: QueueItem) -> Bool {
            switch self {
            case .byTitle:
                lhs.titleLabel < rhs.titleLabel
            case .byAdded:
                lhs.added ?? Date.distantPast < rhs.added ?? Date.distantPast
            }
        }
    }

    var hasFilter: Bool {
        instance != ".all" ||
        type != ".all" ||
        client != ".all" ||
        issues == true
    }
}
