import SwiftUI

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

struct SettingsView: View {
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some View {
        NavigationStack {
            List {
                instanceSection
                settingsSection
                aboutSection
            }
            .animation(.easeInOut, value: instances)
            .navigationTitle("Settings")
        }
    }

    // TODO: convert to `@AppStorage` (default empty list)
    @AppStorage("instances") private var instances: [Instance] = []
    
    // TODO: don't default to `example.com` the fields should all be empty
    private var draftInstance: Instance {
        Instance(label: "", urlString: "")
    }
    
    var instanceSection: some View {
        Group {
            Section(header: Text("Instances")) {
                ForEach(instances) { instance in
                    NavigationLink {
                        InstanceForm(
                            state: .update,
                            instance: instance,
                            saveInstance: { ins in
                                updateInstance(ins)
                            },
                            deleteInstance: { ins in
                                deleteInstance(ins)
                            }
                        )
                    } label: {
                        VStack(alignment: .leading) {
                            Text(instance.label)
                            Text(instance.urlString)
                                .font(.footnote)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                NavigationLink("Add instance") {
                    InstanceForm(
                        state: .add,
                        instance: draftInstance,
                        saveInstance: { ins in
                            saveInstance(ins)
                        }
                    )
                }
            }
            
            if !instances.isEmpty {
                deleteAllInstanceView
            }
        }
    }
    
    var settingsSection: some View {
        Section(header: Text("Preferences")) {
            HStack {
                Toggle(isOn: $darkMode) {
                    Label("Dark Mode", systemImage: "moon")
                }
            }
        }
        .accentColor(.primary)
        .listRowSeparatorTint(.blue)
        .listRowSeparator(.hidden)
    }
    
    var aboutSection: some View {
        Section {
            NavigationLink { ContentView() } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        .accentColor(.primary)
        .listRowSeparatorTint(.blue)
        .listRowSeparator(.hidden)
    }
    
    // TODO: Add button to delete all `@AppStorage` and reset the app
    
    var deleteAllInstanceView: some View {
        Section {
            Button("Delete All Instances") {
                deleteAllInstances()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.red)
        }
    }
}

extension SettingsView {
    func saveInstance(_ instance: Instance) {
        instances.append(instance)
    }
    
    func updateInstance(_ instance: Instance) {
        guard let instanceForUpdation = instances.enumerated().first(where: { $0.element.id == instance.id }) else { return }
        instances.remove(at: instanceForUpdation.offset)
        instances.insert(instance, at: instanceForUpdation.offset)
    }
    
    func deleteInstance(_ instance: Instance) {
        instances.removeAll(where: { $0.id == instance.id })
    }
    
    func deleteAllInstances() {
        withAnimation {
            instances.removeAll()
        }
    }
}

// TODO: only save instance when user clicks on "Done" and the validation passes
struct InstanceForm: View {
    
    enum InstanceState {
        case add
        case update
    }
    
    @Environment (\.dismiss) var dismiss
    
    var state: InstanceState
    @State var instance: Instance = .init(label: "", urlString: "")
    var saveInstance: ((Instance) -> ())
    var deleteInstance: ((Instance) -> ())? = nil
    
    @State var isLoading = false
    @State var errorMessage: String?
    
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
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("API Key")
                            .padding(.trailing)
                        Spacer()
                        TextField("", text: $instance.label)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            // TODO: only show when viewing an instance that was already saved (not a new one)
            if state != .add {
                Section {
                    Button("Delete Instance") {
                        // TODO: delete instance from `@AppStorage`
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
                    // TODO: validate that `URL` field can be reached via HTTP (status code 200?)
                    // TODO: save instance to `@AppStorage` (or update edited instance)
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
                        }
                    }
                }
            }
        }
        .errorToast(with: $errorMessage)
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
        if instance.label.isEmpty || instance.urlString.isEmpty {
            throw ValidationError.fieldsEmpty
        } else {
            try await checkValidationForUrlString(instance.urlString)
        }
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
