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
    let state: FormState

    @State var instance: Instance
    
    enum FormState {
        case create
        case update
    }

    var body: some View {
        Form {
            Section {
                List {
                    HStack {
                        Text("Label")
                            .padding(.trailing)
                            .padding(.trailing)
                        Spacer()
                        TextField("Synology", text: $instance.label.bindNil)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Host")
                            .padding(.trailing)
                            .padding(.trailing)
                        Spacer()
                        TextField("", text: $instance.url.bindNil, prompt: Text(verbatim: "https://10.0.1.1:7878"))
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    HStack {
                        Text("API Key")
                            .padding(.trailing)
                            .padding(.trailing)
                        Spacer()
                        TextField("", text: $instance.apiKey.bindNil)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                }
            }

            if state == .update {
                Section {
                    Button("Delete Instance") {
                        print(instance)
                        print(state)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                }
            }
        }.onSubmit {
            print("submit...")
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Section {
                    Button("Done") {
                        //
                    }
                    .disabled(hasEmptyFields())
                    
                    ProgressView()
                }
            }
        }
    }
    
    func hasEmptyFields() -> Bool {
        return instance.label.bindNil.isEmpty ||
            instance.url.bindNil.isEmpty ||
            instance.apiKey.bindNil.isEmpty
    }
}

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
