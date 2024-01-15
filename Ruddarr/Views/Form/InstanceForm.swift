//
//  InstanceFormView.swift
//  Ruddarr
//
//  Created by Till Krüss on 14/1/24.
//

import SwiftUI

struct InstanceFormView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    InstanceFormView()
}

struct InstanceForm: View {
    
    enum FormState {
        case create
        case update
    }
    
    @Environment (\.dismiss) var dismiss
    
    var state: FormState
    @State var instance: Instance = .init()
    var saveInstance: ((Instance) -> ())
    var deleteInstance: ((Instance) -> ())? = nil
    
    @State var isLoading = false
    @State var showAlert = false
    @State var errorMessage: String = ""
    
    var body: some View {
        Form {
            Section {
                List {
                    HStack {
                        Text("Label")
                            .padding(.trailing)
                        Spacer()
                        TextField("Synology", text: $instance.label)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Host")
                            .padding(.trailing)
                        Spacer()
                        TextField("", text: $instance.urlString)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("API Key")
                            .padding(.trailing)
                        Spacer()
                        TextField("", text: $instance.apiKey)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            if state != .create {
                Section {
                    Button("Delete Instance") {
                        deleteInstance?(instance)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    Task {
                        isLoading = true
                        do {
                            try await checkForValidations()
                            isLoading = false
                            saveInstance(instance)
                            dismiss()
                        } catch let error {
                            isLoading = false
                            errorMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                }
                .disabled(!instance.isValid)
            }
        }
//        .errorToast(with: $errorMessage)
        .alert(errorMessage, isPresented: $showAlert, actions: {
            Button("Ok", role: .cancel, action: {})
        })
        .overlay {
            if isLoading {
                ProgressView()
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func checkForValidations() async throws {
        try await checkValidationForUrlString(instance.urlString)
    }
    
    func checkValidationForUrlString(_ string: String) async throws {
        if let url = URL(string: string) {
            let request = URLRequest(url: url)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode != 200 {
                throw ValidationError.urlNotValid
            }
        } else {
            throw ValidationError.urlNotValid
        }
    }
}

#Preview {
    ContentView(selectedTab: .settings)
        .withSelectedColorScheme()
}


//struct InstanceForm: View {
//    let state: FormState
//
//    @State var instance: Instance
//    
//    
//
//    var body: some View {
//        Form {
//            Section {
//                List {
//                    HStack {
//                        Text("Label")
//                            .padding(.trailing)
//                            .padding(.trailing)
//                        Spacer()
//                        TextField("Synology", text: $instance.label.bindNil)
//                            .multilineTextAlignment(.trailing)
//                    }
//                    HStack {
//                        Text("Host")
//                            .padding(.trailing)
//                            .padding(.trailing)
//                        Spacer()
//                        TextField("", text: $instance.url.bindNil, prompt: Text(verbatim: "https://10.0.1.1:7878"))
//                            .multilineTextAlignment(.trailing)
//                            .textInputAutocapitalization(.never)
//                            .disableAutocorrection(true)
//                            .keyboardType(.URL)
//                    }
//                    HStack {
//                        Text("API Key")
//                            .padding(.trailing)
//                            .padding(.trailing)
//                        Spacer()
//                        TextField("", text: $instance.apiKey.bindNil)
//                            .multilineTextAlignment(.trailing)
//                            .textInputAutocapitalization(.never)
//                            .disableAutocorrection(true)
//                    }
//                }
//            }
//
//            if state == .update {
//                Section {
//                    Button("Delete Instance") {
//                        print(instance)
//                        print(state)
//                    }
//                    .frame(maxWidth: .infinity, alignment: .center)
//                    .foregroundColor(.red)
//                }
//            }
//        }.onSubmit {
//            print("submit...")
//        }.toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                Section {
//                    Button("Done") {
//                        //
//                    }
//                    .disabled(hasEmptyFields())
//                    
//                    ProgressView()
//                }
//            }
//        }
//    }
//    
//    func hasEmptyFields() -> Bool {
//        return instance.label.bindNil.isEmpty ||
//            instance.url.bindNil.isEmpty ||
//            instance.apiKey.bindNil.isEmpty
//    }
//}

enum ValidationError: Error {
    case urlNotValid
    case fieldsEmpty
}

extension ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlNotValid:
            return "URL is not valid"
        case .fieldsEmpty:
            return "All fields are mandatory"
        }
    }
}

extension Optional where Wrapped == String {
    var _bindNil: String? {
        get {
            return self
        }
        set {
            self = newValue
        }
    }

    public var bindNil: String {
        get {
            return _bindNil ?? ""
        }
        set {
            _bindNil = newValue.isEmpty ? nil : newValue
        }
    }
}
