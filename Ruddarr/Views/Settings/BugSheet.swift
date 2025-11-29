import SwiftUI
import CloudKit
import Sentry

struct BugSheet: View {
    private var minimumLength: Int = 50

    @State private var text: String = ""
    @AppStorage("reportEmail") private var email: String = ""

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                emailField
                reportField
            }
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }.tint(.primary)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Submit", systemImage: "paperplane") {
                        sendReport()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canBeSent)
                }
            }
            #if os(macOS)
                .padding(.all)
            #endif
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

            setSentryContext(for: "configuration", settings.context())
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
