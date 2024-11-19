import SwiftUI

final class Platform: Sendable {
    static let current = Platform()

    let deviceId: String
    let deviceType: DeviceType

#if os(macOS)
    private init() {
        deviceId = dependencies.store.string(forKey: "device:id") ?? {
            let id = UUID().uuidString
            dependencies.store.set(id, forKey: "device:id")
            return id
        }()

        deviceType = .mac
    }
#else
    private init() {
        deviceId = DispatchQueue.main.sync {
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        }

        deviceType = DispatchQueue.main.sync {
            switch UIDevice.current.userInterfaceIdiom {
            case .phone: .phone
            case .pad: .pad
            case .vision: .vision
            default: .unspecified
            }
        }
    }
#endif
}

enum DeviceType: String {
    case unspecified
    case phone
    case pad
    case mac
    case vision
}
