import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    var store: UserDefaults
    @Bindable var router = Router.shared
}

extension Dependencies {
    static var live: Self {
        .init(api: .live, store: .live)
    }
}

extension Dependencies {
    static var mock: Self {
        .init(api: .mock, store: /*.mock*/.live)
    }
}

var dependencies: Dependencies = .live
