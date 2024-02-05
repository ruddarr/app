protocol OptionalProtocol {
    associatedtype Wrapped
    var wrappedValue: Wrapped? { get set }
}
extension Optional: OptionalProtocol {
    var wrappedValue: Wrapped? {
        get { self }
        set { self = newValue }
    }
}
