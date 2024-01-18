import Foundation

struct Dependencies {
    var api: API
}
extension Dependencies {
    static var live: Self {
        .init(api: .live)
    }
}
extension Dependencies {
    static var mock: Self {
        .init(api: .mock)
    }
}
var dependencies: Dependencies = .live
