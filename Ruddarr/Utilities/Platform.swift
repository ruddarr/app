import SwiftUI

final class Platform: Sendable {
#if os(macOS)
    static let deviceId: String = {
        dependencies.store.string(forKey: "device:id") ?? {
            let id = UUID().uuidString
            dependencies.store.set(id, forKey: "device:id")
            return id
        }()
    }()

    static let deviceType: DeviceType = .mac
#else
    @MainActor
    static let deviceId: String = {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }()

    @MainActor
    static let deviceType: DeviceType = {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: .phone
        case .pad: .pad
        case .vision: .vision
        default: .unspecified
        }
    }()
#endif
}

enum DeviceType: String {
    case unspecified
    case phone
    case pad
    case mac
    case vision
}
