import SwiftUI

struct QueueSort: Equatable {
    var isAscending: Bool = false
    var option: Option = .byAdded

    var instance: String = .all
    var type: String = .all
    var client: String = .all

    var issues: Bool = false

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }

        case byTitle
        case byAdded
        case byProgress

        var label: some View {
            switch self {
            case .byTitle: Label("Title", systemImage: "textformat.abc")
            case .byAdded: Label("Added", systemImage: "calendar.badge.plus")
            case .byProgress: Label("Progress", systemImage: "gauge")
            }
        }

        func isOrderedBefore(_ lhs: QueueItem, _ rhs: QueueItem) -> Bool {
            switch self {
            case .byTitle:
                lhs.titleLabel < rhs.titleLabel
            case .byAdded:
                lhs.added ?? Date.distantPast < rhs.added ?? Date.distantPast
            case .byProgress:
                lhs.progressFraction < rhs.progressFraction
            }
        }
    }

    func isOrderedBefore(_ lhs: QueueItem, _ rhs: QueueItem) -> Bool {
        switch option {
        case .byProgress:
            isProgressOrderedBefore(lhs, rhs)
        default:
            isAscending ? option.isOrderedBefore(lhs, rhs) : option.isOrderedBefore(rhs, lhs)
        }
    }

    private func isProgressOrderedBefore(_ lhs: QueueItem, _ rhs: QueueItem) -> Bool {
        if lhs.isActivelyDownloading != rhs.isActivelyDownloading {
            return lhs.isActivelyDownloading
        }

        if lhs.progressFraction != rhs.progressFraction {
            return isAscending ? lhs.progressFraction < rhs.progressFraction : lhs.progressFraction > rhs.progressFraction
        }

        return lhs.titleLabel < rhs.titleLabel
    }

    var hasFilter: Bool {
        instance != .all ||
        type != .all ||
        client != .all ||
        issues == true
    }
}
