import SwiftUI
import CloudKit
import Sentry

struct BugSheet: View {
    private var minimumLength: Int = 50

    @State private var email: String = ""
    @State private var text: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email, prompt: Text(verbatim: "salty.pete@shipwreck.org"))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
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
            .navigationBarTitleDisplayMode(.inline)
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
            let scope = await eventScope()
            let eventId = SentrySDK.capture(message: "Bug Report", scope: scope)
            let userFeedback = UserFeedback(eventId: eventId)

            userFeedback.email = email
            userFeedback.comments = text.trimmingCharacters(in: .whitespacesAndNewlines)
            SentrySDK.capture(userFeedback: userFeedback)
        }

        dismiss()
    }

    func eventScope() async -> Scope {
        let scope = Scope()

        return scope

        // scope.setTag(value: "debug_mode", key: "log_level")
        // scope.setExtra(value: "Button XYZ caused a crash", key: "error_context")
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
