import Foundation
import SwiftUI

@Observable
@MainActor
final class Toast {
    nonisolated init() {}

    var currentMessage: Message?

    @ObservationIgnored
    lazy var show: @MainActor (AnyView, MessageType) -> Void = { [weak self] view, type in
        guard let self else { return }
        var message = Message(view: view, type: type)

        if type == .alert {
            message.onDismiss = { [weak self] in
                guard let self else { return }
                withAnimation(self.animation) {
                    self.currentMessage = nil
                }
            }
        }

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(
                type == .error ? .error : .success
            )
        #endif

        withAnimation(self.animation) {
            self.currentMessage = message
        }

        if type != .alert {
            Task {
                try await self.dismissAfterTimeout(message.id)
            }
        }
    }

    @ObservationIgnored
    var timeout: Duration = .seconds(4)
    var animation: Animation? = .snappy

    @ObservationIgnored
    lazy var dismissAfterTimeout: @MainActor (Message.ID) async throws -> Void = { [weak self] in
        guard let self else { return }
        try await Task.sleep(until: .now + self.timeout)

        if self.currentMessage?.id == $0 {
            withAnimation(self.animation) {
                self.currentMessage = nil
            }
        }
    }
}

extension Toast {
    struct Message: Identifiable {
        var id: UUID = .init()
        var view: AnyView
        var type: MessageType
        var onDismiss: (() -> Void)?

        var textColor: Color {
            switch type {
            case .notice, .alert: .primary
            case .error: .red
            }
        }
    }

    enum MessageType {
        case notice
        case error
        case alert
    }

    enum PresetMessage {
        case monitored
        case unmonitored
        case importQueued
        case refreshQueued
        case downloadQueued
        case movieSearchQueued
        case seasonSearchQueued
        case episodeSearchQueued
        case monitoredSearchQueued
        case movieDeleted
        case seriesDeleted
        case seasonDeleted
        case fileDeleted
        case linkCopied
        case reportSent
        case error(String)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func show(_ preset: PresetMessage) {
        switch preset {
        case .monitored:
            custom(text: String(localized: "Monitored"), icon: "bookmark.fill")
        case .unmonitored:
            custom(text: String(localized: "Unmonitored"), icon: "bookmark")
        case .refreshQueued:
            custom(text: String(localized: "Refresh Queued"), icon: "checkmark.circle.fill")
        case .importQueued:
            custom(text: String(localized: "Import Queued"), icon: "checkmark.circle.fill")
        case .downloadQueued:
            custom(text: String(localized: "Download Queued"), icon: "checkmark.circle.fill")
        case .movieSearchQueued:
            custom(text: String(localized: "Movie Search Queued"), icon: "checkmark.circle.fill")
        case .seasonSearchQueued:
            custom(text: String(localized: "Season Search Queued"), icon: "checkmark.circle.fill")
        case .episodeSearchQueued:
            custom(text: String(localized: "Episode Search Queued"), icon: "checkmark.circle.fill")
        case .monitoredSearchQueued:
            custom(text: String(localized: "Monitored Search Queued"), icon: "checkmark.circle.fill")
        case .movieDeleted:
            custom(text: String(localized: "Movie Deleted"), icon: "checkmark.circle.fill")
        case .seriesDeleted:
            custom(text: String(localized: "Series Deleted"), icon: "checkmark.circle.fill")
        case .seasonDeleted:
            custom(text: String(localized: "Season Files Deleted"), icon: "checkmark.circle.fill")
        case .fileDeleted:
            custom(text: String(localized: "File Deleted"), icon: "checkmark.circle.fill")
        case .linkCopied:
            custom(text: String(localized: "Link Copied"), icon: "checkmark.circle.fill")
        case .reportSent:
            custom(text: String(localized: "Bug Report Sent"), icon: "checkmark.circle.fill")
        case .error(let message):
            custom(text: message, icon: "exclamationmark.circle.fill", type: .error)
        }
    }

    func custom(text: String, icon: String? = nil, type: MessageType = .notice) {
        show(AnyView(label(text, icon)), type)
    }

    func alert(title: String, message: String) {
        show(AnyView(alert(title, message)), .alert)
    }

    func label(_ text: String, _ icon: String? = nil) -> any View {
        Label {
            Text(text)
        } icon: {
            if let icon {
                Image(systemName: icon)
            }
        }
        .font(.callout)
        .fontWeight(.semibold)
    }

    func alert(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    func render(_ message: Toast.Message) -> some View {
        Group {
            if let onDismiss = message.onDismiss {
                VStack(alignment: .leading, spacing: 0) {
                    message.view
                        .padding(.horizontal, 30)
                        .padding(.vertical)

                    Button {
                        onDismiss()
                    } label: {
                        Text("OK").fontWeight(.medium)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .buttonSizing(.flexible)
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                .frame(maxWidth: 340)
                .glassEffect(in: RoundedRectangle(cornerRadius: 24))
            } else {
                message.view
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16).stroke(.ultraThinMaterial, lineWidth: 1)
                    )
            }
        }
        .foregroundStyle(message.textColor)
        .padding()
        .transition(.opacity)
        .id(message.id)
        .padding(.bottom, 50)
    }
}

extension View {
    func displayToasts(from toast: Toast = dependencies.toast) -> some View {
        @Environment(\.colorScheme) var colorScheme

        return overlay(alignment: .bottom) {
            if let message = toast.currentMessage {
                toast.render(message)
            }
        }
    }
}

#Preview {
    let toast = Toast()
    toast.show(.reportSent)

    let notice = Toast.Message(
        view: AnyView(toast.label("Monitored", "bookmark.fill")),
        type: .notice
    )

    let error = Toast.Message(
        view: AnyView(toast.label("Something Went Wrong", "exclamationmark.circle.fill")),
        type: .error
    )

    var alert = Toast.Message(
        view: AnyView(toast.alert("URL Not Reachable", "The operation couldn't be completed. (NSURLERRORDOMAIN error - 1011.)")),
        type: .alert
    )
    alert.onDismiss = {}

    return VStack {
        Text(verbatim: "Headline")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity)
            .overlay { toast.render(notice) }

        toast.render(error)

        Spacer().frame(maxHeight: 100)

        Text(verbatim: "Headline")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity)
            .overlay { toast.render(alert) }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottom) {
        if let message = toast.currentMessage {
            toast.render(message)
        }
    }
}
