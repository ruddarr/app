import SwiftUI

struct InstanceEditView: View {
    let mode: Mode

    @State var instance: Instance

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) var radarrInstance
    @Environment(SonarrInstance.self) var sonarrInstance
    @Environment(\.dismiss) var dismiss

    @State var isLoading = false
    @State var showingAlert = false
    @State var showingConfirmation = false
    @State var error: InstanceError?

    @State var showAdvanced: Bool = false
    @State var showBasicAuthentication = false
    @State var username: String = ""
    @State var password: String = ""

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

            #if DEBUG
                Button {
                    instance.url = "http://10.0.1.5:8310/settings/general"
                    instance.apiKey = "3b0600c1b3aa42bfb0222f4e13a81f39"
                } label: { Text(verbatim: "Radarr") }

                Button {
                    instance.url = "http://10.0.1.5:8989/"
                    instance.apiKey = "f8e3682b3b984cddbaa00047a09d0fbd"
                } label: { Text(verbatim: "Sonarr") }

                Button {
                    instance.url = "http://10.0.1.5:18988"
                    instance.apiKey = "8efa9412e9564d588cefadc4d4cd1b06"
                } label: { Text(verbatim: "Sonarr v3") }
            #endif
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarButton
        }
        .onAppear {
            showAdvanced = instance.mode.isSlow || !instance.headers.isEmpty
        }
        .onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await createOrUpdateInstance()
            }
        }
        .alert(isPresented: $showingAlert, error: error) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .alert("Basic Authentication", isPresented: $showBasicAuthentication, actions: {
            TextField("Username", text: $username)
            SecureField("Password", text: $password)
            Button("Add Header", role: .confirm) {
                let auth = Data("\(username):\(password)".utf8).base64EncodedString()
                instance.headers.append(InstanceHeader(name: "Authorization", value: "Basic \(auth)"))
            }
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("The credentials will be encoded and added as an \"Authorization\" header.")
        })
        .tint(nil)
    }

    var instanceSection: some View {
        Section {
            typeField
            labelField
            urlField
        } footer: {
            Text("The URL used to access the \(instance.type.rawValue) web interface.")
                #if os(macOS)
                .foregroundStyle(.secondary)
                .font(.footnote)
                #endif
        }
    }

    var apiKeySection: some View {
        Section {
            apiKeyField
        } header: {
            Text("Authentication")
                #if os(macOS)
                .padding(.top)
                #endif
        } footer: {
            VStack(alignment: .leading, spacing: 12) {
                Text("The API Key can be found in the web interface under \"Settings > General > Security\".")
                    #if os(macOS)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    #endif

                if !showAdvanced {
                    Text("Show Advanced Settings")
                        .foregroundStyle(settings.theme.tint)
                        .onTapGesture {
                            withAnimation { showAdvanced = true }
                        }
                }
            }.transaction { transaction in
                transaction.animation = nil // disable animation
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
        HStack(spacing: 24) {
            Text("Label", comment: "Instance label/name")
                .layoutPriority(2)

            TextField(text: $instance.label, prompt: Text(verbatim: instance.type.rawValue)) { EmptyView() }
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled(true)
        }
    }

    var urlField: some View {
        HStack(spacing: 24) {
            Text("URL")
                .layoutPriority(2)

            TextField(text: $instance.url, prompt: Text(verbatim: urlPlaceholder)) { EmptyView() }
                .truncationMode(.head)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
                .onChange(of: instance.url, detectInstanceType)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif

        }
    }

    var apiKeyField: some View {
        HStack(spacing: 24) {
            Text("API Key")
                .layoutPriority(2)

            TextField(text: $instance.apiKey, prompt: Text(verbatim: "0a1b2c3d...")) { EmptyView() }
                .truncationMode(.head)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
    }

    var modeSection: some View {
        Section {
            Toggle("Slow Instance", isOn: Binding(
                get: {
                    instance.mode == .slow
                },
                set: { value in
                    instance.mode = value ? .slow : .normal
                }
            ))
            #if os(macOS)
            .padding(.top)
            #endif
        } footer: {
            Text("Optimizes API calls for instances that load unusually slowly and encounter timeouts frequently.")
                #if os(macOS)
                .foregroundStyle(.secondary)
                .font(.footnote)
                #endif
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

            Button {
                instance.headers.append(InstanceHeader())
            } label: {
                Text("Add Header", comment: "Add HTTP Header to instance")
            }

            Button {
                showBasicAuthentication = true
            } label: {
                Text("Add Authentication", comment: "Add Basic HTTP Authentication to instance")
            }
        } header: {
            HStack {
                Text("Headers", comment: "HTTP Headers")
                Spacer()
                pasteButton(pasteHeader)
            }
            #if os(macOS)
            .padding(.top)
            #endif
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Headers can be used to access instances protected by Zero Trust services.")
                Text("Basic Authentication is for advanced server management tools and will not work with regular \(instance.type.rawValue) login credentials.")
            }
            #if os(macOS)
            .foregroundStyle(.secondary)
            .font(.footnote)
            #endif
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
        .tint(nil)
    }

    func pasteButton(_ callback: @escaping () -> Void) -> some View {
        #if os(macOS)
            EmptyView()
        #else
            Button(String(localized: "Paste", comment: "Paste from clipboard"), action: callback)
                .buttonStyle(.plain)
                .foregroundStyle(settings.theme.tint)
        #endif
    }

    @ToolbarContentBuilder
    var toolbarButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button{
                Task { await createOrUpdateInstance() }
            } label: {
                if isLoading {
                    ProgressView().tint(nil)
                } else {
                    #if os(macOS)
                        Text("Save")
                    #else
                        Label("Save", systemImage: "checkmark")
                    #endif
                }
            }
            .prominentGlassButtonStyle(!isLoading)
            .tint(settings.theme.tint)
            .disabled(hasEmptyFields())
        }
    }
}

struct InstanceHeaderRow: View {
    @Binding var header: InstanceHeader

    var body: some View {
        VStack {
            TextField("Header name", text: $header.name)
            .autocorrectionDisabled(true)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif

            TextField("Header value", text: $header.value)
            .autocorrectionDisabled(true)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
        }
    }
}

enum InstanceError: Error {
    case urlIsLocal
    case urlNotValid
    case urlNotOpenable
    case urlSchemeMissing
    case labelEmpty
    case badAppName(_ reported: String, _ expected: String)
    case apiError(_ error: API.Error)
}

extension InstanceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlIsLocal, .urlNotValid, .urlNotOpenable, .urlSchemeMissing:
            return String(localized: "Invalid URL")
        case .labelEmpty:
            return String(localized: "Invalid Instance Label")
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
        case .urlNotOpenable:
            return String(localized: "Device cannot open URL, possibly restricted by Screen Time.")
        case .urlSchemeMissing:
            return String(localized: "URL must start with \"http://\" or \"https://\".")
        case .labelEmpty:
            return String(localized: "Enter an instance label.")
        case .badAppName(let reported, let expected):
            return String(localized: "URL identified itself as a \(reported) instance, not a \(expected) instance.")
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
