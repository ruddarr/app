import SwiftUI

extension EnvironmentValues {
    @Entry var deviceType: DeviceType = .unspecified
    @Entry var presentBugSheet: Binding<Bool> = .constant(false)

    // swiftlint:disable:next implicit_optional_initialization
    @Entry var inCalendarSheet: CalendarSheetContext? = nil
}
