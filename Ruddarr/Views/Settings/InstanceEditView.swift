import SwiftUI

struct InstanceEditView: View {
    let mode: Mode

    @State var instance: Instance

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var radarrInstance

    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var showingConfirmation = false
    @State private var error: InstanceError?

    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case create
        case update
    }

    var body: some View {
        Form {
            Section {
                typeField
                labelField
                urlField
            } footer: {
                Text("The URL used to access the \(instance.type.rawValue) web interface. Must be prefixed with \"http://\" or \"https://\".")
            }

            Section {
                apiKeyField
            } header: {
                Text("Authentication")
            } footer: {
                Text("The API Key can be found in the web interface under \"Settings > General > Security\".")
            }

            Section {
                headersSection
            } header: {
                Text("Headers")
            } footer: {
                Text("Custom headers are an advanced feature, only needed to access instances protected by zero trust services.")
            }

            if mode == .update {
                Section {
                    deleteInstance
                }
            }

            #if DEBUG
                debugQuickFill
            #endif
        }
        .onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await createOrUpdateInstance()
            }
        }
        .toolbar {
            toolbarButton
        }
        .alert(isPresented: $showingAlert, error: error) { _ in
            Button("OK") { }
        } message: { error in
            Text(error.recoverySuggestion ?? "Try again later.")
        }
    }

    var typeField: some View {
        Picker("Type", selection: $instance.type) {
            ForEach(InstanceType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .tint(.secondary)
    }

    var labelField: some View {
        LabeledContent {
            TextField("Synology", text: $instance.label)
                .multilineTextAlignment(.trailing)
        } label: {
            Text("Label")
        }
    }

    var urlField: some View {
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
    }

    var apiKeyField: some View {
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

    var headersSection: some View {
        Group {
            ForEach($instance.headers.indices, id: \.self) { index in
                InstanceHeaderRow(header: $instance.headers[index])
                    .swipeActions {
                        Button("Delete") {
                            instance.headers.remove(at: index)
                        }
                        .tint(.red)
                    }
            }

            Button("Add header") {
                print(instance.headers)
                instance.headers.append(InstanceHeader())
            }
        }
    }

    var urlPlaceholder: String {
        switch instance.type {
        case .radarr: "https://10.0.1.42:7878"
        case .sonarr: "https://10.0.1.42:8989"
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

    @ToolbarContentBuilder
    var toolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isLoading {
                ProgressView().tint(.secondary)
            } else {
                Button("Done") {
                    Task {
                        await createOrUpdateInstance()
                    }
                }
                .disabled(hasEmptyFields())
            }
        }
    }

    var debugQuickFill: some View {
        Group {
            Button("Use Synology") {
                instance.label = "Till"
                instance.url = Instance.till.url
                instance.apiKey = Instance.till.apiKey
            }

            Button("Use Digital Ocean") {
                self.instance.label = "Digital Ocean"
                self.instance.url = Instance.digitalOcean.url
                self.instance.apiKey = Instance.digitalOcean.apiKey
            }
        }
    }
}

extension InstanceEditView {
    @MainActor
    func createOrUpdateInstance() async {
        do {
            isLoading = true

            sanitizeInstanceUrl()
            try await validateInstance()

            settings.saveInstance(instance)

            dismiss()
        } catch let error as InstanceError {
            isLoading = false
            showingAlert = true
            self.error = error
        } catch {
            fatalError("Failed to save instance")
        }
    }

    func hasEmptyFields() -> Bool {
        instance.label.isEmpty || instance.url.isEmpty || instance.apiKey.isEmpty
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
            throw InstanceError.urlNotValid
        }

        if !UIApplication.shared.canOpenURL(url) {
            throw InstanceError.urlNotValid
        }

        if ["localhost", "127.0.0.1"].contains(url.host()) {
            throw InstanceError.urlIsLocal
        }

        var status: InstanceStatus?

        do {
            status = try await dependencies.api.systemStatus(instance)
        } catch API.Error.badStatusCode(code: let code) {
            throw InstanceError.badStatusCode(code)
        } catch API.Error.errorResponse(code: let code, message: let message) {
            throw InstanceError.errorResponse(code, message)
        } catch let error as DecodingError {
            throw InstanceError.badResponse(error)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw instance.isPrivateIp()
                ? InstanceError.timedOutOnPrivateIp(URLError.timedOutOnPrivateIp)
                : InstanceError.urlNotReachable(urlError)
        } catch {
            throw InstanceError.urlNotReachable(error)
        }

        guard let appName = status?.appName else {
            return
        }

        if appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
            throw InstanceError.badAppName(appName)
        }

        instance.version = status!.version
    }
}

struct InstanceHeaderRow: View {
    @Binding var header: InstanceHeader

    var body: some View {
        LabeledContent {
            TextField("Value", text: $header.value)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        } label: {
            TextField("Name", text: $header.name)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
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
