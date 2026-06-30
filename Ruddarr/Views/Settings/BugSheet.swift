import SwiftUI
import CloudKit
import Sentry

struct BugSheet: View {
    private var minimumLength: Int = 50

    @State private var text: String = ""
    @AppStorage("reportEmail") private var email: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            Form {
                emailField
                reportField
            }
            .formStyle(.grouped)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .tint(.primary)
                    .hideIconOnMac()
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Submit", systemImage: "paperplane") {
                        sendReport()
                    }
                    .buttonStyle(.glassProminent)
                    .hideIconOnMac()
                    .disabled(!canBeSent)
                }
            }
        }
    }

    var emailField: some View {
        Section {
            TextField("Email", text: $email, prompt: Text(verbatim: "salty.pete@shipwreck.org"))
                #if os(macOS)
                    .labelsHidden()
                #else
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                #endif
        } header: {
            Text("Email")
        }
    }

    var reportField: some View {
        Section {
            TextField("What happened?", text: $text, axis: .vertical)
                .lineLimit(5, reservesSpace: true)
                .overlay(alignment: .bottomTrailing) {
                    Text(verbatim: "\(text.count) / \(minimumLength)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(text.count < minimumLength ? 1 : 0)
                }
                #if os(macOS)
                    .labelsHidden()
                #endif
        } header: {
            Text("Details")
        } footer: {
            Text("Provide a detailed description of the issue along with the exact steps to reproduce it.")
        }
    }

    var canBeSent: Bool {
        text.count >= minimumLength && email.trimmed().isValidEmail()
    }

    func sendReport() {
        Task {
            defer {
                dependencies.toast.show(.reportSent)
                dismiss()
                text = ""
            }

            setSentryContext(for: "Configuration", settings.context())
            setSentryContext(for: "Subscription", await Subscription.context())
            await setSentryCloudKitContext()

            let eventId = SentrySDK.capture(message: "Bug Report (\(UUID().shortened))")

            let feedback = SentryFeedback(
                message: text.trimmed(),
                name: nil,
                email: email.lowercased().trimmed(),
                source: .custom,
                associatedEventId: eventId
            )

            SentrySDK.capture(feedback: feedback)
        }
    }
}

extension View {
    func reportBugSheet() -> some View {
        self.modifier(BugSheetViewModifier())
    }
}

private struct BugSheetViewModifier: ViewModifier {
    @State private var isPresented: Bool = false

    func body(content: Content) -> some View {
        content
            .environment(\.presentBugSheet, $isPresented)
            .sheet(isPresented: $isPresented) {
                BugSheet()
                    .presentationDetents(dynamic: [.medium])
                    .presentationBackground(.sheetBackground)
            }
    }
}

#Preview {
    @Previewable @Environment(\.presentBugSheet) var presentBugSheet

    Button {
        presentBugSheet.wrappedValue = true
    } label: {
        Text(verbatim: "Open")
    }
}
