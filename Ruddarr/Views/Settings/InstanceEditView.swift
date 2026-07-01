import SwiftUI

struct InstanceEditView: View {
    let mode: Mode

    @State var instance: Instance

    @Environment(AppSettings.self) var settings
    @Environment(RadarrInstance.self) var radarrInstance
    @Environment(SonarrInstance.self) var sonarrInstance

    @Environment(\.dismiss) var dismiss
    @Environment(\.deviceType) private var deviceType

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

            #if !os(macOS)
                if mode == .update {
                    Section {
                        deleteButton
                    }
                }
            #endif
        }
        .formStyle(.grouped)
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
                .autocorrectionDisabled(true)
                #if os(iOS)
                .multilineTextAlignment(.trailing)
                #endif
        }
    }

    var urlField: some View {
        HStack(spacing: 24) {
            Text("URL")
                .layoutPriority(2)

            TextField(text: $instance.url, prompt: Text(verbatim: urlPlaceholder)) { EmptyView() }
                .truncationMode(.head)
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
                .onChange(of: instance.url, detectInstanceType)
                #if os(iOS)
                .multilineTextAlignment(.trailing)
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
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
                #if os(iOS)
                .multilineTextAlignment(.trailing)
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
            #if os(macOS)
                .buttonStyle(.link)
                .foregroundStyle(settings.theme.tint)
            #endif

            Button {
                showBasicAuthentication = true
            } label: {
                Text("Add Authentication", comment: "Add Basic HTTP Authentication to instance")
            }
            #if os(macOS)
                .buttonStyle(.link)
                .foregroundStyle(settings.theme.tint)
            #endif
        } header: {
            HStack {
                Text("Headers", comment: "HTTP Headers")
                Spacer()
                pasteButton(pasteHeader)
            }
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
        Button(deviceType == .mac ? "Delete" : "Delete Instance", role: .destructive) {
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
            Button {
                Task { await createOrUpdateInstance() }
            } label: {
                if isLoading {
                    ButtonProgressView()
                } else {
                    Label("Save", systemImage: "checkmark")
                        .hideIconOnMac()
                }
            }
            .prominentGlassButtonStyle(!isLoading)
            .tint(settings.theme.tint)
            .disabled(hasEmptyFields())
        }

        #if os(macOS)
            if mode == .update {
                ToolbarItem(placement: .destructiveAction) {
                    deleteButton
                }
            }
        #endif
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
    case urlSchemeMissing
    case labelEmpty
    case localNetworkDenied
    case badAppName(_ reported: String, _ expected: String)
    case apiError(_ error: API.Error)
}

extension InstanceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlIsLocal, .urlNotValid, .urlSchemeMissing:
            String(localized: "Invalid URL")
        case .labelEmpty:
            String(localized: "Invalid Instance Label")
        case .localNetworkDenied:
            String(localized: "Local Network Access Denied")
        case .badAppName:
            String(localized: "Wrong Instance Type")
        case .apiError(let error):
            error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .urlIsLocal:
            String(localized: "URLs must be non-local, \"localhost\" and \"127.0.0.1\" will not work.")
        case .urlNotValid:
            String(localized: "Enter a valid URL.")
        case .urlSchemeMissing:
            String(localized: "URL must start with \"http://\" or \"https://\".")
        case .labelEmpty:
            String(localized: "Enter an instance label.")
        case .localNetworkDenied:
            String(localized: "Local network access must be granted in System Settings to connect to instances on private IP addresses.")
        case .badAppName(let reported, let expected):
            String(localized: "URL identified itself as a \(reported) instance, not a \(expected) instance.")
        case .apiError(let error):
            error.recoverySuggestion
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
        .macPreviewFrame()
}
