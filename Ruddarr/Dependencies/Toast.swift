import Foundation
import SwiftUI

@Observable
@MainActor
final class Toast {
    nonisolated init() {}

    var currentMessage: Message?

    @ObservationIgnored
    var animation: Animation? = .snappy

    @ObservationIgnored
    lazy var trigger: @MainActor (AnyView, MessageType) -> Void = { [weak self] view, type in
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
            try? await self.dismissAfterTimeout(message.id, message.timeout)
        }
    }

    @ObservationIgnored
    lazy var dismissAfterTimeout: @MainActor (Message.ID, Duration) async throws -> Void = { [weak self] id, duration in
        guard let self else { return }
        try await Task.sleep(until: .now + duration)

        if self.currentMessage?.id == id {
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

        var tint: Color {
            switch type {
            case .notice: .primary
            case .error: .red
            }
        }

        var timeout: Duration {
            switch type {
            case .notice: return .seconds(4)
            case .error: return .seconds(8)
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
        case indexerEnabled
        case indexerDisabled
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
            notice(text: String(localized: "Monitored"), icon: "bookmark.fill")
        case .unmonitored:
            notice(text: String(localized: "Unmonitored"), icon: "bookmark")
        case .indexerEnabled:
            notice(text: String(localized: "Indexer Enabled"), icon: "checkmark.circle.fill")
        case .indexerDisabled:
            notice(text: String(localized: "Indexer Disabled"), icon: "checkmark.circle.fill")
        case .refreshQueued:
            notice(text: String(localized: "Refresh Queued"), icon: "checkmark.circle.fill")
        case .importQueued:
            notice(text: String(localized: "Import Queued"), icon: "checkmark.circle.fill")
        case .downloadQueued:
            notice(text: String(localized: "Download Queued"), icon: "checkmark.circle.fill")
        case .movieSearchQueued:
            notice(text: String(localized: "Movie Search Queued"), icon: "checkmark.circle.fill")
        case .seasonSearchQueued:
            notice(text: String(localized: "Season Search Queued"), icon: "checkmark.circle.fill")
        case .episodeSearchQueued:
            notice(text: String(localized: "Episode Search Queued"), icon: "checkmark.circle.fill")
        case .monitoredSearchQueued:
            notice(text: String(localized: "Monitored Search Queued"), icon: "checkmark.circle.fill")
        case .movieDeleted:
            notice(text: String(localized: "Movie Deleted"), icon: "checkmark.circle.fill")
        case .seriesDeleted:
            notice(text: String(localized: "Series Deleted"), icon: "checkmark.circle.fill")
        case .seasonDeleted:
            notice(text: String(localized: "Season Files Deleted"), icon: "checkmark.circle.fill")
        case .fileDeleted:
            notice(text: String(localized: "File Deleted"), icon: "checkmark.circle.fill")
        case .linkCopied:
            notice(text: String(localized: "Link Copied"), icon: "checkmark.circle.fill")
        case .reportSent:
            notice(text: String(localized: "Bug Report Sent"), icon: "checkmark.circle.fill")
        case .error(let message):
            error(text: message, icon: "exclamationmark.circle.fill")
        }
    }

    func notice(text: String, icon: String? = nil) {
        trigger(AnyView(label(text, icon)), .notice)
    }

    func error(text: String, icon: String? = nil) {
        trigger(AnyView(label(text, icon)), .error)
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
        .lineLimit(1)
    }

    func render(_ message: Toast.Message) -> some View {
        message.view
            .padding()
            .glassEffect()
            .overlay(
                Capsule().stroke(.ultraThinMaterial, lineWidth: 1)
            )
            .foregroundStyle(message.tint)
            .scenePadding(.horizontal)
            .scenePadding(.horizontal)
            .frame(maxWidth: 600)
            .padding(.bottom)
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
        view: AnyView(toast.label(
            "The operation couldn't be completed. (NSURLERRORDOMAIN error - 1011.)",
            "exclamationmark.circle.fill"
        )),
        type: .error
    )

    return VStack {
        Text(verbatim: "Headline")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity)
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
