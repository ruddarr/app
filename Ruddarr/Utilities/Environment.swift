import SwiftUI

private struct DeviceTypeKey: EnvironmentKey {
    static let defaultValue: DeviceType = .unspecified
}

struct PresentBugSheetKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

private struct WhatsNewIsPresentedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var deviceType: DeviceType {
        get { self[DeviceTypeKey.self] }
        set { self[DeviceTypeKey.self] = newValue }
    }

    var presentBugSheet: Binding<Bool> {
        get { self[PresentBugSheetKey.self] }
        set { self[PresentBugSheetKey.self] = newValue }
    }

    var whatsNewIsPresented: Bool {
        get { self[WhatsNewIsPresentedKey.self] }
        set { self[WhatsNewIsPresentedKey.self] = newValue }
    }
}
