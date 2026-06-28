import os
import SwiftUI

let dependencies: Dependencies = .live

struct Dependencies: Sendable {
    static var live: Self {
        .init(api: .live)
    }

    static var mock: Self {
        .init(api: .mock)
    }

    let quickActions = QuickActions()

    private let apiLock: OSAllocatedUnfairLock<API>
    private let cloudkitLock: OSAllocatedUnfairLock<CloudKit>

    @Bindable var router = Router()
    @Bindable var toast = Toast()

    var store: UserDefaults { .live }

    var api: API {
        get { apiLock.withLock { $0 } }
        nonmutating set { apiLock.withLock { $0 = newValue } }
    }

    var cloudkit: CloudKit {
        get { cloudkitLock.withLock { $0 } }
        nonmutating set { cloudkitLock.withLock { $0 = newValue } }
    }

    init(api: API, cloudkit: CloudKit = .live) {
        self.apiLock = OSAllocatedUnfairLock(initialState: api)
        self.cloudkitLock = OSAllocatedUnfairLock(initialState: cloudkit)
    }

    enum CloudKit: Sendable {
        case live
        case mock
    }
}
