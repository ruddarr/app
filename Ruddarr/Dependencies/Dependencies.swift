import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    @Bindable var router = Router.shared
    var userDefaults: UserDefaults
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
