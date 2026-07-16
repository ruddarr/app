import SwiftUI

struct InstanceEditView: View {
    let mode: Mode
    var openAdvanced: Bool = false

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
        .contentMargins(.bottom, 32, for: .scrollContent)
        .formStyle(.grouped)
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarButton
        }
        .onAppear {
            showAdvanced = openAdvanced || instance.mode.isSlow || !instance.headers.isEmpty
        }
        .onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await createOrUpdateInstance()
            }
        }
        .sensoryAlert(isPresented: $showingAlert, error: error) { _ in
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

    var showsAlternateURL: Bool {
        showAdvanced || !instance.alternateURL.isEmpty
    }

    var instanceSection: some View {
        Section {
            typeField
            labelField
            urlField

            if showsAlternateURL {
                alternateField
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("The URL used to access the \(instance.type.rawValue) web interface.")

                if showsAlternateURL {
                    Text("When using an Alternate URL, \(Ruddarr.name) automatically connects to the best URL for the network, whether local, VPN, or remote.")
                }
            }
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

            TextField(text: $instance.url, prompt: urlPlaceholders.url) { EmptyView() }
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

    var alternateField: some View {
        HStack(spacing: 24) {
            Text("Alternate URL")
                .layoutPriority(2)

            TextField(text: $instance.alternateURL, prompt: urlPlaceholders.alternate) { EmptyView() }
                .truncationMode(.head)
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
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

    var ipPlaceholder: String {
        switch instance.type {
        case .radarr: "10.0.1.1:7878"
        case .sonarr: "10.0.1.1:8989"
        }
    }

    var tldPlaceholder: String {
        switch instance.type {
        case .radarr: "radarr.home.net"
        case .sonarr: "sonarr.home.net"
        }
    }

    var urlPlaceholders: (url: Text, alternate: Text) {
        let ip = Text(verbatim: ipPlaceholder)
        let tld = Text(verbatim: tldPlaceholder)

        let alternate = hostIsIPAddress(instance.url) == false ? ip : tld
        let url = hostIsIPAddress(instance.alternateURL) == true ? tld : ip

        return (url: url, alternate: alternate)
    }

    func hostIsIPAddress(_ string: String) -> Bool? {
        guard let host = NetworkInterfaces.host(of: string) else { return nil }
        return NetworkInterfaces.parseIPv4(host) != nil || NetworkInterfaces.parseIPv6(host) != nil
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

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.createInstance
    )

    return ContentView()
        .withAppState()
        .macPreviewFrame()
}
