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

extension String {
    var untrailingSlashIt: String? {
        var string = self

        while string.hasSuffix("/") {
            string = String(string.dropLast())
        }

        return string
    }
}
