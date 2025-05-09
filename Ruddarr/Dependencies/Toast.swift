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
        let message = Message(view: view, type: type)

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(
                type == .error ? .error : .success
            )
        #endif

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
        case importQueued
        case refreshQueued
        case downloadQueued
        case movieSearchQueued
        case seasonSearchQueued
        case episodeSearchQueued
        case monitoredSearchQueued
        case movieDeleted
        case seriesDeleted
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

    func render(_ message: Toast.Message) -> some View {
        message.view
            .padding()
            #if os(macOS)
                .background(.systemFill)
            #else
                .background(.ultraThinMaterial)
            #endif
            .foregroundStyle(message.textColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
    toast.show(.monitored)

    let notice = Toast.Message(
        view: AnyView(toast.label("Monitored", "bookmark.fill")),
        type: .notice
    )

    let error = Toast.Message(
        view: AnyView(toast.label("Something Went Wrong", "exclamationmark.circle.fill")),
        type: .error
    )

    return VStack {
        Text(verbatim: "Headline")
            .font(.largeTitle.bold())
            .overlay { toast.render(notice) }

        toast.render(error)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottom) {
        if let message = toast.currentMessage {
            toast.render(message)
        }
    }
}
