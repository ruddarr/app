import SwiftUI

extension EnvironmentValues {
    @Entry var deviceType: DeviceType = .unspecified
    @Entry var isFolded: Bool = false
    @Entry var presentBugSheet: Binding<Bool> = .constant(false)

    // swiftlint:disable:next implicit_optional_initialization
    @Entry var inCalendarSheet: CalendarSheetContext? = nil

    var hasVerticalToolbar: Bool {
        #if os(iOS)
            if #available(iOS 27.1, *) {
                return toolbarVerticalEdge != nil
            }
        #endif

        return false
    }
}

enum EnvironmentType: String {
    case preview
    case simulator
    case debug
    case testflight
    case appstore

    static let cached: EnvironmentType = {
        guard let branch = Bundle.main.object(forInfoDictionaryKey: "CI_BRANCH") as? String else {
            return .appstore
        }

        return branch.contains("develop") ? .testflight : .appstore
    }()
}

func isRunningIn(_ env: EnvironmentType) -> Bool {
    runningIn() == env
}

func runningIn() -> EnvironmentType {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        return .preview
    }

#if targetEnvironment(simulator)
    return .simulator
#elseif DEBUG
    return .debug
#else
    return EnvironmentType.cached
#endif
}
