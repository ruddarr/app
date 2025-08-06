import Foundation


protocol SimpleInitializable {
    init()
}
protocol DefaultValueProvider {
    associatedtype Value
    static var defaultValue: Value { get }
}
struct SimpleDefaultValueProvider<Value>: DefaultValueProvider where Value: SimpleInitializable {
    static var defaultValue: Value { .init() }
}

@propertyWrapper
struct WithDefault<DefaultProvider: DefaultValueProvider> {
    typealias Value = DefaultProvider.Value
    var wrappedValue: Value
}
typealias WithSimpleDefault<Value> = WithDefault<SimpleDefaultValueProvider<Value>> where Value: SimpleInitializable

extension WithDefault: Codable where Value: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(wrappedValue: container.decodeNil() ? DefaultProvider.defaultValue : container.decode(Value.self))
    }
}
extension WithDefault: Equatable where Value: Equatable {}
extension WithDefault: Hashable where Value: Hashable {}
extension WithDefault: Identifiable where Value: Identifiable {
    var id: Value.ID { wrappedValue.id }
}
extension WithDefault: Sendable where Value: Sendable {}


//MARK: basic conformances

extension Array: SimpleInitializable {}
