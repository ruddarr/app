import Foundation
import SwiftUI

extension Binding {
    @MainActor
    func onSet(_ action: @escaping (Value) -> Void) -> Self {
        Self {
            wrappedValue
        } set: {
            wrappedValue = $0
            action($0)
        }
    }
}
