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

    enum Mode {
        case create
        case update
    }

    var body: some View {
        Form {
            instanceSection
            apiKeySection
            headersSection

            if mode == .update {
                Section {
                    deleteButton
                }
            }

            #if DEBUG
                debugQuickFill
            #endif
        }
        .navigationBarTitleDisplayMode(.inline)
        .onSubmit {
            guard !hasEmptyFields() else { return }

            Task {
                await createOrUpdateInstance()
            }
        }
        .toolbar {
            toolbarButton
        }
        .alert(isPresented: $showingAlert, error: error) { _ in } message: { error in
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
            Text("The API Key can be found in the web interface under \"Settings > General > Security\".")
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
        } header: {
            HStack {
                Text("Headers")
                Spacer()
                pasteButton(pasteHeader)
            }
        } footer: {
            Text("Custom headers are an advanced feature, only needed to access instances protected by zero trust services.")
        }
    }

    var urlPlaceholder: String {
        switch instance.type {
        case .radarr: "https://10.0.1.42:7878"
        case .sonarr: "https://10.0.1.42:8989"
        }
    }

    var deleteButton: some View {
        Button("Delete Instance", role: .destructive) {
            showingConfirmation = true
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .confirmationDialog("Are you sure?", isPresented: $showingConfirmation) {
            Button("Delete Instance", role: .destructive) { deleteInstance() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete the instance?")
        }
    }

    func pasteButton(_ callback: @escaping () -> Void) -> some View {
        Button("Paste", action: callback)
            .buttonStyle(PlainButtonStyle())
            .foregroundStyle(settings.theme.tint)
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
