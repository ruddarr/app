import SwiftUI

private struct DeviceTypeKey: EnvironmentKey {
    static let defaultValue: DeviceType = .unspecified
}

extension EnvironmentValues {
    var deviceType: DeviceType {
        get { self[DeviceTypeKey.self] }
        set { self[DeviceTypeKey.self] = newValue }
    }
}
