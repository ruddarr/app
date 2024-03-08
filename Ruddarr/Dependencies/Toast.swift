import Foundation
import SwiftUI

@Observable
final class Toast {
    var currentMessage: Message?

    @ObservationIgnored
    lazy var show: (AnyView, MessageType) -> Void = { [weak self] view, type in
        guard let self else { return }
        let message = Message(view: view, type: type)

        UINotificationFeedbackGenerator().notificationOccurred(
            type == .error ? .error : .success
        )

        withAnimation(self.animation) {
            self.currentMessage = message
        }

        Task {
            try await self.dismissAfterTimeout(message.id)
        }
    }

    @ObservationIgnored
    var timeout: Duration = .seconds(4)
    var animation: Animation? = .snappy

    @ObservationIgnored
    lazy var dismissAfterTimeout: (Message.ID) async throws -> Void = { @MainActor [weak self] in
        guard let self else { return }
        try await Task.sleep(until: .now + self.timeout)

        if self.currentMessage?.id == $0 {
            withAnimation {
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

        var textColor: Color {
            switch type {
            case .notice: .primary
            case .error: .red
            }
        }
    }

    enum MessageType {
        case notice
        case error
    }

    enum PresetMessage {
        case monitored
        case unmonitored
        case refreshQueued
        case searchQueued
        case downloadQueued
        case movieDeleted
        case error(String)
    }

    func show(_ preset: PresetMessage) {
        switch preset {
        case .monitored:
            custom(text: String(localized: "Monitored"), icon: "bookmark.fill")
        case .unmonitored:
            custom(text: String(localized: "Unmonitored"), icon: "bookmark")
        case .refreshQueued:
            custom(text: String(localized: "Refresh Queued"), icon: "checkmark.circle.fill")
        case .searchQueued:
            custom(text: String(localized: "Search Queued"), icon: "checkmark.circle.fill")
        case .downloadQueued:
            custom(text: String(localized: "Download Queued"), icon: "checkmark.circle.fill")
        case .movieDeleted:
            custom(text: String(localized: "Movie Deleted"), icon: "checkmark.circle.fill")
        case .error(let message):
            custom(text: message, icon: "exclamationmark.circle.fill", type: .error)
        }
    }

    func custom(text: String, icon: String? = nil, type: MessageType = .notice) {
        let label = Label {
            Text(text)
        } icon: {
            if let icon {
                Image(systemName: icon)
            }
        }
        .font(.callout)
        .fontWeight(.semibold)

        show(AnyView(label), type)
    }
}

extension View {
    func displayToasts(from toast: Toast = dependencies.toast) -> some View {
        overlay(alignment: .bottom) {
            if let message = toast.currentMessage {
                message.view
                    .padding()
                    .background(.ultraThinMaterial)
                    .foregroundStyle(message.textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .transition(.opacity)
                    .id(message.id)
            }
        }
    }
}
