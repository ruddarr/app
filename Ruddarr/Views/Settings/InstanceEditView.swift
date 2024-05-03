import SwiftUI

struct InstanceEditView: View {
    let mode: Mode

    @State var instance: Instance

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) var radarrInstance

    @State var isLoading = false
    @State var showingAlert = false
    @State var showingConfirmation = false
    @State var error: InstanceError?

    @State var showAdvanced: Bool = false
    @State var showBasicAuthentication = false
    @State var username: String = ""
    @State var password: String = ""

    @State var hotfixId = UUID()
    @Environment(\.scenePhase) private var scenePhase

    enum Mode {
        case create
        case update
    }

    var body: some View {
        Form {
            instanceSection
            apiKeySection

            if showAdvanced {
                headersSection
                modeSection
            }

            if mode == .update {
                Section {
                    deleteButton
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarButton
        }
        .onAppear {
            showAdvanced = instance.mode != .normal || !instance.headers.isEmpty
        }
        .onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await createOrUpdateInstance()
            }
        }
        .onChange(of: scenePhase) { hotfixId = UUID() }
        .alert(isPresented: $showingAlert, error: error) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }

    var instanceSection: some View {
        Section {
            typeField
            labelField
            urlField
        } footer: {
            Text("The URL used to access the \(instance.type.rawValue) web interface. Must be prefixed with \"http://\" or \"https://\".")
        }
    }

    var apiKeySection: some View {
        Section {
            apiKeyField
        } header: {
            Text("Authentication")
        } footer: {
            VStack(alignment: .leading, spacing: 12) {
                Text("The API Key can be found in the web interface under \"Settings > General > Security\".")

                if !showAdvanced {
                    Text("Show Advanced Settings")
                        .foregroundStyle(.tint)
                        .onTapGesture {
                            withAnimation { showAdvanced = true }
                        }
                }
            }
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
                .disableAutocorrection(true)
        } label: {
            Text("Label")
        }
    }

    var urlField: some View {
        LabeledContent {
            TextField(text: $instance.url, prompt: Text(verbatim: urlPlaceholder)) { EmptyView() }
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textCase(.lowercase)
                .keyboardType(.URL)
                .onChange(of: instance.url, detectInstanceType)
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

    var modeSection: some View {
        Section {
            Toggle("Large Instance", isOn: Binding(
                get: {
                    instance.mode == .large
                },
                set: { value in
                    instance.mode = value ? .large : .normal
                }
            ))
        } footer: {
            Text("Optimize API calls for instances that load slowly.")
        }
    }

    var headersSection: some View {
        Section {
            ForEach($instance.headers.indices, id: \.self) { index in
                InstanceHeaderRow(header: $instance.headers[index])
                    .swipeActions {
                        Button("Delete") {
                            instance.headers.remove(at: index)
                        }
                        .tint(.red)
                    }
            }

            Button("Add Header") {
                instance.headers.append(InstanceHeader())
            }

            Button("Add Authentication") {
                showBasicAuthentication = true
            }
            .alert("Basic Authentication", isPresented: $showBasicAuthentication, actions: {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                Button("Add Header") {
                    let auth = Data("\(username):\(password)".utf8).base64EncodedString()
                    instance.headers.append(InstanceHeader(name: "Authorization", value: "Basic \(auth)"))
                }
                Button("Cancel", role: .cancel, action: {})
            }, message: {
                Text("The credentials will be encoded and added as an \"Authorization\" header.")
            })
        } header: {
            HStack {
                Text("Headers")
                Spacer()
                pasteButton(pasteHeader)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Headers can be used to access instances protected by Zero Trust services.")
                Text("Basic Authentication is for advanced server management tools and will not work with the \(instance.type.rawValue) instance login.")
            }
        }
    }

    var urlPlaceholder: String {
        switch instance.type {
        case .radarr: "http://10.0.1.1:7878"
        case .sonarr: "http://10.0.1.1:8989"
        }
    }

    var deleteButton: some View {
        Button("Delete Instance", role: .destructive) {
            showingConfirmation = true
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .alert(
            "Are you sure you want to delete the instance?",
            isPresented: $showingConfirmation
        ) {
            Button("Delete Instance", role: .destructive) { deleteInstance() }
            Button("Cancel", role: .cancel) { }
        }
    }

    func pasteButton(_ callback: @escaping () -> Void) -> some View {
        Button("Paste", action: callback)
            .buttonStyle(PlainButtonStyle())
            .foregroundStyle(settings.theme.tint)
    }

    @ToolbarContentBuilder
    var toolbarButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isLoading {
                ProgressView().tint(.secondary)
            } else {
                Button("Done") {
                    Task { await createOrUpdateInstance() }
                }
                .id(hotfixId) // somehow `.id(UUID())` doesn't work in this case
                .disabled(hasEmptyFields())
            }
        }
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

enum InstanceError: Error {
    case urlIsLocal
    case urlNotValid
    case labelEmpty
    case badAppName(_ name: String)
    case apiError(_ error: API.Error)
}

extension InstanceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlIsLocal, .urlNotValid:
            return String(localized: "Invalid URL")
        case .labelEmpty:
            return String(localized: "Invalid Label")
        case .badAppName:
            return String(localized: "Wrong Instance Type")
        case .apiError(let error):
            return error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .urlIsLocal:
            return String(localized: "URLs must be non-local, \"localhost\" and \"127.0.0.1\" will not work.")
        case .urlNotValid:
            return String(localized: "Enter a valid URL.")
        case .labelEmpty:
            return String(localized: "Enter an instance label.")
        case .badAppName(let name):
            return String(localized: "URL returned is a \(name) instance.")
        case .apiError(let error):
            return error.recoverySuggestion
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
