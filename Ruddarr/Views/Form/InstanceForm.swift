import SwiftUI

struct InstanceForm: View {
    let state: FormState

    @State var instance: Instance

    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var showingConfirmation = false
    @State private var error: ValidationError?

    @AppStorage("movieInstance") private var movieInstance: UUID?
    @AppStorage("instances") private var instances: [Instance] = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                List {
                    Picker("Type", selection: $instance.type) {
                        ForEach(InstanceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    LabeledContent {
                        TextField("Synology", text: $instance.label)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Text("Label")
                    }

                    LabeledContent {
                        TextField("", text: $instance.url, prompt: Text(verbatim: urlPlaceholder))
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textCase(.lowercase)
                            .keyboardType(.URL)
                    } label: {
                        Text("URL")
                    }

                    LabeledContent {
                        TextField("0a1b2c3d...", text: $instance.apiKey)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textCase(.lowercase)
                    } label: {
                        Text("API Key")
                    }
                }
            } footer: {
                Text("The API Key can be found under \"Settings > General > Security\".")
            }

            if state == .update {
                Section {
                    deleteInstance
                }
            }
        }.onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await saveInstance()
            }
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button("Done") {
                        Task {
                            await saveInstance()
                        }
                    }
                    .disabled(hasEmptyFields())
                }
            }
        }.alert(isPresented: $showingAlert, error: error) { _ in
            Button("OK") { }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try again later.")
        }
    }

    var urlPlaceholder: String {
        switch instance.type {
        case .radarr: "https://10.0.1.1:7878"
        case .sonarr: "https://10.0.1.1:8989"
        }
    }

    var deleteInstance: some View {
        Button("Delete Instance") {
            showingConfirmation = true
        }
        .confirmationDialog("Are you sure?", isPresented: $showingConfirmation) {
            Button("Delete instance", role: .destructive) {
                if movieInstance == instance.id {
                    movieInstance = nil
                }

                guard let index = instances.firstIndex(where: { $0.id == instance.id }) else { return }
                instances.remove(at: index)

                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete the instance?")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension InstanceForm {
    @MainActor
    func saveInstance() async {
        do {
            isLoading = true

            try await validateInstance()

            switch state {
            case .create:
                instances.append(instance)
            case .update:
                guard let index = instances.firstIndex(where: { $0.id == instance.id }) else { return }
                instances[index] = instance
            }

            dismiss()
        } catch let error as ValidationError {
            isLoading = false
            showingAlert = true
            self.error = error
        } catch {
            fatalError()
        }
    }

    func hasEmptyFields() -> Bool {
        return instance.label.isEmpty || instance.url.isEmpty || instance.apiKey.isEmpty
    }

    func validateInstance() async throws {
        let rawUrl = URL(string: instance.url)!

        // strip path from URL
        var components = URLComponents(url: rawUrl, resolvingAgainstBaseURL: false)!
        components.path = ""

        let url = components.url!
        instance.url = url.absoluteString

        if await !UIApplication.shared.canOpenURL(url) {
            throw ValidationError.urlNotValid
        }

        let statusUrl = URL(string: "\(url)/api/v3/system/status")!

        var status: InstanceStatus?
        var error: ApiError?

        await Api<InstanceStatus>.call(
            url: statusUrl,
            authorization: instance.apiKey
        ) { data in
            status = data
        } failure: { err in
            error = err
        }

        if status?.appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
            throw ValidationError.badAppName(status!.appName)
        }

        switch error {
        case .badStatusCode(let code):
            throw ValidationError.badStatusCode(code)
        case .requestFailure(let error):
            throw ValidationError.urlNotReachable(error)
        default:
            assertionFailure("Unhandled error")
        }
    }
}

enum FormState {
    case create
    case update
}

enum ValidationError: Error {
    case urlNotValid
    case urlNotReachable(_ error: Error)
    case badStatusCode(_ code: Int)
    case badAppName(_ name: String)
}

extension ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlNotValid:
            return "Invalid URL"
        case .urlNotReachable:
            return "Server Not Reachable"
        case .badStatusCode:
            return "Invalid Status Code"
        case .badAppName:
            return "Wrong Instance Type"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .urlNotValid:
            return "Enter a valid URL."
        case .urlNotReachable(let error):
            return error.localizedDescription
        case .badStatusCode(let code):
            return "URL returned status \(code)."
        case .badAppName(let name):
            return "URL returned a \(name) instance."
        }
    }
}

#Preview {
    InstanceForm(
        state: .create,
        // instance: Instance()
        instance: Instance(url: "HTTP://10.0.1.5:8310/api", apiKey: "8f45bce99e254f888b7a2ba122468dbe")
        // instance: Instance(url: "http://10.0.1.5:8989/api", apiKey: "f8e3682b3b984cddbaa00047a09d0fbd")
    ).withSelectedColorScheme()
}
