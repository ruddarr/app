import Foundation
import SwiftUI
// we need this boilerplate to store Codable stuff in AppStorage. Swift currently makes it hard to make this fully generic.
//extension Array<Instance>: RawRepresentable {
//    public init?(rawValue: String) {
//        guard let data = rawValue.data(using: .utf8),
//            let result = try? JSONDecoder().decode([Instance].self, from: data)
//        else {
//            return nil
//        }
//        self = result
//    }
//
//    public var rawValue: String {
//        guard let data = try? JSONEncoder().encode(self),
//            let result = String(data: data, encoding: .utf8)
//        else {
//            return "[]"
//        }
//        return result
//    }
//}

extension UUID: RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }

    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}

// I think we can only conform Array once, if we need more, we'll need to start wrapping it in another type.
extension Array<Instance>: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

//struct C: Codable {}
//extension C: RawRepresentable {
//struct V: View {
//    
//}

//extension MovieSort: RawRepresentable {
//    
//}
