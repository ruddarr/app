import Defaults
import Foundation

extension Defaults.Keys {
    #if DEBUG
        static let instances = Key<[Instance]>("debugInstances", default: [])
    #else
        static let instances = Key<[Instance]>("instances", default: [], iCloud: true)
    #endif

    static let icon = Key<AppIcon>("icon", default: .factory, suite: dependencies.store)
    static let theme = Key<Theme>("theme", default: .factory, suite: dependencies.store)
    static let appearance = Key<Appearance>("appearance", default: .automatic, suite: dependencies.store)
    static let grid = Key<GridStyle>("grid", default: .posters, suite: dependencies.store)
    static let tab = Key<TabItem>("tab", default: .movies, suite: dependencies.store)
    static let releaseFilters = Key<ReleaseFilters>("releaseFilters", default: .reset, suite: dependencies.store)

    static let radarrInstanceId = Key<Instance.ID?>("radarrInstanceId", default: nil, suite: dependencies.store)
    static let sonarrInstanceId = Key<Instance.ID?>("sonarrInstanceId", default: nil, suite: dependencies.store)
}
