import SwiftUI

@main
struct RuddarrApp: App {
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkMode ? .dark : .light)
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

//extension Optional where Wrapped == String {
//    var _bindNil: String? {
//        get {
//            return self
//        }
//        set {
//            self = newValue
//        }
//    }
//    
//    public var bindNil: String {
//        get {
//            return _bindNil ?? ""
//        }
//        set {
//            _bindNil = newValue.isEmpty ? nil : newValue
//        }
//    }
//}
