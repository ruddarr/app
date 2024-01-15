import SwiftUI

struct YourStruct {
    var yourEnumProperty: YourEnum
}

enum YourEnum: String, CaseIterable {
    case option1
    case option2
    case option3
    // Add more cases as needed
}

struct ContentView2: View {
    @State private var yourStructInstance = YourStruct(yourEnumProperty: .option1)

    var body: some View {
        VStack {
            Picker("Select an option", selection: $yourStructInstance.yourEnumProperty) {
                ForEach(YourEnum.allCases, id: \.self) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }

            Text("Selected option: \(yourStructInstance.yourEnumProperty.rawValue)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView2()
    }
}
