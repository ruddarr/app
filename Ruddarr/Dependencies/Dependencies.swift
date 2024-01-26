import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    var store: UserDefaults
    @Bindable var router = Router.shared
}

extension Dependencies {
    static var live: Self {
        .init(api: .live, store: .standard)
    }
}

extension Dependencies {
    static var mock: Self {
        .init(api: .mock, store: .live)
    }
}

var dependencies: Dependencies = .live
