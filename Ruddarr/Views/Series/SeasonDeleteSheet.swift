import SwiftUI

struct SeasonDeleteSheet: View {
    var label: LocalizedStringKey
    var confirm: (_ unmonitor: Bool) -> Void

    @State private var unmonitor: Bool = true
    @State private var isWorking: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Unmonitor downloaded episodes", isOn: $unmonitor)
                        .tint(settings.theme.safeTint)
                } footer: {
                    Text("Only episodes with downloaded files will be unmonitored")
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
                            confirm(unmonitor)
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
    Text(verbatim: "Preview")
        .sheet(isPresented: .constant(true)) {
            SeasonDeleteSheet(label: "Delete Season Files") { _ in
                //
            }
            .presentationDetents(
                dynamic: [.fraction(0.33)]
            )
        }
        .withAppState()
}
