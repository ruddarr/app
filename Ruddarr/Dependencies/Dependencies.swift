import SwiftUI

struct Dependencies {
    var api: API
    var store: UserDefaults
    var quickActions: QuickActions = .init()
    var cloudkit: CloudKit = .live

    @Bindable var router = Router()
    @Bindable var toast = Toast()

    enum CloudKit {
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

nonisolated(unsafe) var dependencies: Dependencies = .live
