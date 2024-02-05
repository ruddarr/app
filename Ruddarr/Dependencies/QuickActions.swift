import Foundation
import UIKit

struct QuickActions {
    var register: () -> Void = {
        UIApplication.shared.shortcutItems = Action.allCases.map(\.shortcutItem)
    }
    
    var handle: (Action) -> Void = { action in
        switch action {
        case .addMovie:
            dependencies.router.goToSearch()
        }
    }
}

extension QuickActions {
    enum Action: String, CaseIterable {
        case addMovie
        
        var title: String {
            switch self {
            case .addMovie:
                "Add Movie"
            }
        }
        var icon: UIApplicationShortcutIcon {
            switch self {
            case .addMovie:
                UIApplicationShortcutIcon(type: .add)
            }
        }
    }
}
extension QuickActions.Action {
    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(type: rawValue, localizedTitle: title, localizedSubtitle: "", icon: icon)
    }
    
    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }
}
