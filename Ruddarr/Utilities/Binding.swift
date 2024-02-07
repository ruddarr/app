import SwiftUI

extension Binding {
    func onSet(_ action: @escaping (Value) -> Void = { _ in }) -> Self {
        .init {
            wrappedValue
        } set: {
            action($0)
            wrappedValue = $0
        }
    }
}

extension Binding {
    var optional: Binding<Value?> {
        .init {
            wrappedValue
        } set: {
            if let value = $0 {
                wrappedValue = value
            }
        }
    }
}

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
