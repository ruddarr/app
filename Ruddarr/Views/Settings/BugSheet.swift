import SwiftUI
import CloudKit
import Sentry

struct BugSheet: View {
    private var minimumLength: Int = 50

    @SceneStorage("reportEmail") private var email: String = ""
    @SceneStorage("reportText") private var text: String = ""

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email, prompt: Text(verbatim: "salty.pete@shipwreck.org"))
                        #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Email")
                }

                Section {
                    TextField("What happened?", text: $text, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                        .overlay(alignment: .bottomTrailing) {
                            Text(verbatim: "\(text.count) / \(minimumLength)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .opacity(text.count < minimumLength ? 1 : 0)
                        }
                } header: {
                    Text("Details")
                } footer: {
                    Text("Provide a detailed description of the issue along with the exact steps to reproduce it.")
                }
            }
            .navigationTitle("Report a Bug")
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Submit", action: sendReport)
                        .disabled(text.count < minimumLength)
                }
            }
        }
    }

    func sendReport() {
        Task {
            defer {
                dependencies.toast.show(.reportSent)
                dismiss()
                text = ""
            }

            setSentryContext(for: "configuration", settings.context())
            await setSentryContext(from: CKContainer.default())

            let eventId = SentrySDK.capture(message: "Bug Report (\(UUID().shortened))")

            let feedback = SentryFeedback(
                message: text.trimmingCharacters(in: .whitespacesAndNewlines),
                name: nil,
                email: email.lowercased(),
                source: .custom,
                associatedEventId: eventId
            )

            SentrySDK.capture(feedback: feedback)
        }
    }

}

#Preview {
    @Previewable @State var showBugSheet: Bool = true

    Text(verbatim: "Hello")
        .sheet(isPresented: $showBugSheet) {
            BugSheet()
                .presentationDetents([.medium])
        }
}
