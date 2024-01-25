import Foundation

struct MovieSort {
    var isAscending: Bool = true
    var option: Option = .byTitle

    enum Option: CaseIterable, Hashable, Identifiable, Codable {
        var id: Self { self }
        case byTitle
        case byYear
        case byAdded

        var title: String {
            switch self {
            case .byTitle: "Title"
            case .byYear: "Year"
            case .byAdded: "Added"
            }
        }

        func isOrderedBefore(_ lhs: Movie, _ rhs: Movie) -> Bool {
            switch self {
            case .byTitle:
                lhs.sortTitle < rhs.sortTitle
            case .byYear:
                lhs.year < rhs.year
            case .byAdded:
                lhs.added < rhs.added
            }
        }
    }
}

extension MovieSort: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}

extension MovieSort: Codable {
    enum CodingKeys: String, CodingKey {
        case option
        case isAscending
    }
    
    // !!! this is needed. If we don't implement encode ourselves, JSONEncoder will try to optimize by calling RawRepresentable.rawValue and end up in a loop
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(option, forKey: .option)
        try container.encode(isAscending, forKey: .isAscending)
    }
}
