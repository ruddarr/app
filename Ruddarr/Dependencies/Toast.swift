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

        withAnimation(self.animation) {
            self.currentMessage = message
        }

        Task {
            try await self.dismissAfterTimeout(message.id)
        }
    }

    @ObservationIgnored
    var timeout: Duration = .seconds(3)
    var animation: Animation? = .spring

    @ObservationIgnored
    lazy var dismissAfterTimeout: (Message.ID) async throws -> Void = { [weak self] in
        guard let self else { return }
        try await Task.sleep(until: .now + self.timeout)

        if self.currentMessage?.id == $0 {
            self.currentMessage = nil
        }
    }
}

extension Toast {
    func show(text: String, icon: String? = nil) {
        show(
            AnyView(
                Label {
                    Text(text)
                } icon: {
                    if let icon {
                        Image(systemName: icon)
                    }
                }
            )
        )
    }
}

extension View {
    func displayMessages(from toast: Toast = dependencies.toast) -> some View {
        overlay(alignment: .bottom) {
            if let currentMessage = toast.currentMessage {
                currentMessage.view
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .transition(.move(edge: .bottom))
                    .id(currentMessage.id)
            }
        }
    }
}
