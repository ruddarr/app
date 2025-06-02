import SwiftUI

struct MediaDeleteSheet: View {
    var label: LocalizedStringKey
    var confirm: (_ addExclusion: Bool, _ deleteFiles: Bool) -> Void

    @State private var delete: Bool = false
    @State private var exclude: Bool = false
    @State private var isWorking: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Add Exclusion", isOn: $exclude)
                        .tint(settings.theme.safeTint)
                } footer: {
                    Text("Prevent from being readded to library by lists.")
                }

                Section {
                    Toggle("Delete Files", isOn: $delete)
                        .tint(settings.theme.safeTint)
                } footer: {
                    Text("Permanently erase the folder and its contents.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isWorking {
                        ProgressView().tint(.secondary)
                    } else {
                        Button(role: .destructive) {
                            isWorking = true
                            confirm(exclude, delete)
                        } label: {
                            Text(label)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            #if os(macOS)
                .padding(.all)
            #else
                .padding(.top, -25)
            #endif
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            MediaDeleteSheet(label: "Delete Movie") { _, _ in
                //
            }
            .presentationDetents(
                dynamic: [.fraction(0.33)]
            )
        }
        .withAppState()
}
