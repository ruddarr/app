import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    @Bindable var router = Router.shared
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
