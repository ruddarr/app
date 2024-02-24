import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    var store: UserDefaults
    @Bindable var router = Router.shared
    @Bindable var toast = Toast()
    var quickActions: QuickActions = .init()

    // this is an environmentObject but also made available through dependencies for movie lookup by tmbdID (and possibly more)
    var radarrInstance: RadarrInstance?
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
