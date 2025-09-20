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
                toolbarCloseButton
                toolbarDeleteButton
            }
            #if os(macOS)
                .padding(.all)
            #else
                .padding(.top, -25)
            #endif
        }
    }

    var toolbarCloseButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(.primary)
        }
    }

    var toolbarDeleteButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(role: .destructive) {
                isWorking = true
                confirm(exclude, delete)
            } label: {
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Label("Delete", systemImage: "trash")
                }
            }
            .tint(.red)
            .buttonStyle(.glassProminent)
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
