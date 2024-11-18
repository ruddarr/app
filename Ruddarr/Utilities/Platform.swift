import SwiftUI

class Platform {
    @MainActor
    static func deviceId() -> String {
        #if os(macOS)
            "unknown (macOS)"
        #else
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #endif
    }

    @MainActor
    static func deviceType() -> DeviceType {
        #if os(macOS)
            .mac
        #else
            switch UIDevice.current.userInterfaceIdiom {
            case .phone: .phone
            case .pad: .pad
            case .vision: .vision
            default: .unspecified
            }
        #endif
    }
}

enum DeviceType: String {
    case unspecified
    case phone
    case pad
    case mac
    case vision
}
