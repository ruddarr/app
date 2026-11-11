import Foundation

/// A custom filter as `/api/v3/customfilter` sends and takes it. `id` is omitted when creating one.
struct CustomFilterResource: Codable, Equatable, Sendable {
    var id: Int?
    var type: String
    var label: String
    var filters: [CustomFilterCondition]

    /// `filter` for the server, without an `id` unless it already lives there.
    init(_ filter: CustomFilter, type: String) {
        if case .server(let id) = filter.id { self.id = id }

        self.type = type
        self.label = filter.label
        self.filters = filter.conditions
    }

    /// The filter, or `nil` when the server didn't send an `id`.
    var customFilter: CustomFilter? {
        guard let id else { return nil }
        return CustomFilter(id: .server(id), label: label, conditions: filters)
    }
}
