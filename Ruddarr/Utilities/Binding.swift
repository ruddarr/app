import SwiftUI

extension Binding where Value: OptionalProtocol {
    var unwrapped: Binding<Value.Wrapped>? {
        guard var wrappedValue = self.wrappedValue.wrappedValue else {
            return nil
        }

        return .init {
            wrappedValue
        } set: {
            wrappedValue = $0
            self.wrappedValue.wrappedValue = wrappedValue
        }
    }
}
