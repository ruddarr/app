import SwiftUI

struct InstanceView: View {
    let mode: Mode

    @State var instance: Instance

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance

    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var showingConfirmation = false
    @State private var error: ValidationError?

    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case create
        case update
    }

    var body: some View {
        Form {
            Section {
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
            }

            Section {
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

            } footer: {
                Text("The URL used to access the web interface. Do not use `localhost` or `127.0.0.1`. Must be prefixed with `http://` or `https://`.")
            }

            Section {
                LabeledContent {
                    TextField("0a1b2c3d...", text: $instance.apiKey)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textCase(.lowercase)
                } label: {
                    Text("API Key")
                }
            } footer: {
                Text("The API Key can be found in the web interface under \"Settings > General > Security\".")
            }

            if mode == .update {
                Section {
                    deleteInstance
                }
            }

            #if DEBUG
                Button("Use Synology") {
                    self.instance = Instance.till
                    self.instance.label = "Till"
                }
                Button("Use Digital Ocean") {
                    self.instance = Instance.digitalOcean
                    self.instance.label = "Digital Ocean"
                }
            #endif
        }.onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await saveInstance()
            }
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView().tint(.secondary)
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
        Button("Delete Instance", role: .destructive) {
            showingConfirmation = true
        }
        .confirmationDialog("Are you sure?", isPresented: $showingConfirmation) {
            Button("Delete Instance", role: .destructive) {
                if instance.id == settings.radarrInstanceId {
                    dependencies.router.reset()
                    radarrInstance.switchTo(.void)
                }

                settings.deleteInstance(instance)

                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete the instance?")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension InstanceView {
    @MainActor
    func saveInstance() async {
        do {
            isLoading = true

            sanitizeInstanceUrl()
            try await validateInstance()

            settings.saveInstance(instance)

            dismiss()
        } catch let error as ValidationError {
            isLoading = false
            showingAlert = true
            self.error = error
        } catch {
            fatalError("Failed to save instance")
        }
    }

    func hasEmptyFields() -> Bool {
        return instance.label.isEmpty || instance.url.isEmpty || instance.apiKey.isEmpty
    }

    func sanitizeInstanceUrl() {
        if let url = URL(string: instance.url) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.path = ""

            if let urlWithoutPath = components.url {
                instance.url = urlWithoutPath.absoluteString
            }
        }

        instance.url = instance.url.lowercased()
    }

    func validateInstance() async throws {
        guard let url = URL(string: instance.url) else {
            throw ValidationError.urlNotValid
        }

        if !UIApplication.shared.canOpenURL(url) {
            throw ValidationError.urlNotValid
        }

        var status: InstanceStatus?

        do {
            status = try await dependencies.api.systemStatus(instance)
        } catch API.Error.badStatusCode(code: let code) {
            throw ValidationError.badStatusCode(code)
        } catch API.Error.errorResponse(code: let code, message: let message) {
            throw ValidationError.errorResponse(code, message)
        } catch let error as DecodingError {
            throw ValidationError.badResponse(error)
        } catch {
            throw ValidationError.urlNotReachable(error)
        }

        guard let appName = status?.appName else {
            return
        }

        if appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
            throw ValidationError.badAppName(appName)
        }

        instance.version = status!.version
    }
}

enum ValidationError: Error {
    case urlNotValid
    case urlNotReachable(_ error: Error)
    case badAppName(_ name: String)
    case badStatusCode(_ code: Int)
    case badResponse(_ error: Error)
    case errorResponse(_ code: Int, _ message: String)
}

extension ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlNotValid:
            return "Invalid URL"
        case .urlNotReachable:
            return "URL Not Reachable"
        case .badAppName:
            return "Wrong Instance Type"
        case .badStatusCode:
            return "Invalid Status Code"
        case .badResponse:
            return "Invalid Server Response"
        case .errorResponse:
            return "Server Error Response"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .urlNotValid:
            return "Enter a valid URL."
        case .urlNotReachable(let error):
            return error.localizedDescription
        case .badAppName(let name):
            return "URL returned a \(name) instance."
        case .badStatusCode(let code):
            return "URL returned status \(code)."
        case .badResponse(let error):
            return error.localizedDescription
        case .errorResponse(let code, let message):
            return "[\(code)] \(message)"
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.createInstance
    )

    return ContentView()
        .withAppState()
}
