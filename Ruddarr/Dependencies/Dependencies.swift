import SwiftUI

struct Dependencies {
    var api: API
    var store: UserDefaults
    var quickActions: QuickActions = .init()

    var cloudkit: State = .live

    @Bindable var router = Router.shared
    @Bindable var toast = Toast()

    enum State {
        case live
        case mock
    }
}

extension Dependencies {
    static var live: Self {
        .init(api: .live, store: .live)
    }
}

extension Dependencies {
    static var mock: Self {
        .init(api: .mock, store: .live)
    }
}

var dependencies: Dependencies = .live
