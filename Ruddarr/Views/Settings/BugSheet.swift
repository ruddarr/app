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
            let id = UUID().uuidString.prefix(8).lowercased()
            let scope = await eventScope()
            let eventId = SentrySDK.capture(message: "Bug Report \(id)", scope: scope)
            let userFeedback = UserFeedback(eventId: eventId)

            userFeedback.email = email.lowercased()
            userFeedback.comments = text.trimmingCharacters(in: .whitespacesAndNewlines)
            SentrySDK.capture(userFeedback: userFeedback)
        }

        dependencies.toast.show(.reportSent)
        dismiss()
        text = ""
    }

    func eventScope() async -> Scope {
        let scope = Scope()

        var context: [String: Any] = [
            "icon": settings.icon.rawValue,
            "theme": settings.theme.rawValue,
            "tab": settings.tab.rawValue,
            "appearance": settings.appearance.rawValue,
        ]

        for instance in settings.configuredInstances {
            let id = instance.id.uuidString.prefix(6).lowercased()
            let type = instance.type.rawValue.lowercased()

            context["\(type)-\(id)"] = [
                "type": instance.type.rawValue,
                "mode": instance.mode.value,
                "version": instance.version as Any,
            ]
        }

        scope.setContext(value: context, key: "configuration")

        return scope
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
