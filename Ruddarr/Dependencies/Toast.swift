import Foundation
import SwiftUI

@Observable
final class Toast {
    struct Message: Identifiable {
        var id: UUID = .init()
        var view: AnyView
    }

    var currentMessage: Message?

    @ObservationIgnored
    lazy var show: (AnyView) -> Void = { [weak self] in
        guard let self else { return }
        let message = Message(view: $0)

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        withAnimation(self.animation) {
            self.currentMessage = message
        }

        Task {
            try await self.dismissAfterTimeout(message.id)
        }
    }

    @ObservationIgnored
    var timeout: Duration = .seconds(3)
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
    enum PresetMessage {
        case monitored
        case unmonitored
        case refreshQueued
        case searchQueued
        case movieDeleted
    }

    func show(_ preset: PresetMessage) {
        switch preset {
        case .monitored:
            custom(text: "Monitored", icon: "bookmark.fill")
        case .unmonitored:
            custom(text: "Unmonitored", icon: "bookmark")
        case .refreshQueued:
            custom(text: "Refresh Queued", icon: "checkmark.circle.fill")
        case .searchQueued:
            custom(text: "Search Queued", icon: "checkmark.circle.fill")
        case .movieDeleted:
            custom(text: "Movie Deleted", icon: "checkmark.circle.fill")
        }
    }

    func custom(text: String, icon: String? = nil) {
        show(
            AnyView(
                Label {
                    Text(text)
                } icon: {
                    if let icon {
                        Image(systemName: icon)
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
            )
        )
    }
}

extension View {
    func displayToasts(from toast: Toast = dependencies.toast) -> some View {
        overlay(alignment: .bottom) {
            if let currentMessage = toast.currentMessage {
                currentMessage.view
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .transition(.opacity)
                    .id(currentMessage.id)
            }
        }
    }
}
