import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    var userDefaults: UserDefaults
    @Bindable var router = Router.shared
}

extension Dependencies {
    static var live: Self {
        .init(api: .live, userDefaults: .standard)
    }
}

extension Dependencies {
    static var mock: Self {
        .init(api: .mock, userDefaults: .live)
    }
}

var dependencies: Dependencies = .live
