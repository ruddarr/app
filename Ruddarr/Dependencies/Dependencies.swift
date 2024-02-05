import Foundation
import SwiftUI

struct Dependencies {
    var api: API
    var store: UserDefaults
    @Bindable var router = Router.shared
    @Bindable var messageCenter = MessageCenter()
}

extension Dependencies {
    static var live: Self {
        .init(api: .live, store: .live)
    }
}

extension Dependencies {
    static var mock: Self {
        .init(api: .mock, store: .live)
        // TODO: Our UserDefaults.mock is broken
    }
}

var dependencies: Dependencies = .live
