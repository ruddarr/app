import Foundation
import SwiftUI

@Observable
final class MessageCenter {
    struct Message: Equatable {
        var id: UUID = .init()
        var text: String
    }
    var currentMessage: Message?
    
    @ObservationIgnored
    lazy var show: (String) -> Void = { [weak self] in
        guard let self else { return }
        let message = Message(text: $0)
        self.currentMessage = message
        Task {
            try await self.dismissAfterTimeout(message)
        }
    }
    
    @ObservationIgnored
    var timeout: Duration = .seconds(3)
    @ObservationIgnored
    lazy var dismissAfterTimeout: (Message) async throws -> Void = { [weak self] in
        guard let self else { return }
        try await Task.sleep(until: .now + self.timeout)
        if self.currentMessage == $0 {
            self.currentMessage = nil
        }
    }
}

extension View {
    func displayMessages(from messageCenter: MessageCenter = dependencies.messageCenter) -> some View {
        overlay(alignment: .bottom) {
            if let currentMessage = messageCenter.currentMessage {
                Text(currentMessage.text)
                    .padding()
                    .background(.thinMaterial)
                    .id(currentMessage.id)
            }
        }
    }
}


