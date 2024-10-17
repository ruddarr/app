import SwiftUI

struct QueueItemSheet: View {
    var item: QueueItem

    @State private var showRemovalSheet = false

    @EnvironmentObject var settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        ScrollView {
            ZStack(alignment: .topTrailing) {
                CloseButton {
                    dismiss()
                }

                VStack(alignment: .leading) {
                    header

                    if item.trackedDownloadStatus != .ok && !item.messages.isEmpty {
                        GroupBox {
                            statusMessages
                        }
                    } else if let remaining = item.remainingLabel {
                        ProgressView(value: item.sizeleft, total: item.size) {
                            HStack {
                                Text(item.progressLabel)
                                Spacer()
                                Text(remaining)
                            }
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        }
                    }

                    details
                        .padding(.top)

                    actions
                        .padding(.top)

                    Spacer()
                }
                .viewPadding(.horizontal)
                .padding(.top)
            }
        }
    }

    @ViewBuilder
    var header: some View {
        Text(item.extendedStatusLabel)
            .foregroundStyle(settings.theme.tint)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(1.1)

        Text(item.title ?? "Unknown")
            .font(.title3.bold())
            .kerning(-0.5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.trailing, 40)

        HStack(spacing: 6) {
            Text(item.quality.quality.label)
            Bullet()
            Text(formatBytes(Int(item.size)))
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }

    var statusMessages: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(item.messages, id: \.self) { status in
                VStack(alignment: .leading) {
                    Text(status.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(status.messages, id: \.self) { message in
                        Text(message)
                            .font(.footnote.italic())
                    }
                }
            }
        }
    }

    var details: some View {
        VStack(spacing: 6) {
            row("Languages", item.languagesLabel)

            if let score = item.scoreLabel {
                Divider()
                row("Score", score)
            }

            if let formats = item.customFormatsLabel {
                Divider()
                row("Custom Formats", formats)
            }

            if let indexer = item.indexer {
                Divider()
                row("Indexer", formatIndexer(indexer))
            }

            Divider()
            row("Protocol", item.type.label)

            Divider()
            row("Client", item.downloadClient ?? "--")

            if let date = item.added {
                Divider()
                row("Added", date.formatted(date: .long, time: .shortened))
            }
        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            Button {
                showRemovalSheet = true
            } label: {
                let label: LocalizedStringKey = deviceType == .phone ? "Remove" : "Remove Task"

                ButtonLabel(text: label, icon: "trash")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .sheet(isPresented: $showRemovalSheet) {
                QueueTaskRemovalSheet(item: item) {
                    dismiss()
                }
                    .presentationDetents([.medium])
                    .environmentObject(settings)
            }

            if item.downloadClient == "SABnzbd" && sableInstalled() {
                Link(destination: URL(string: "sable://open")!, label: {
                    Group {
                        if deviceType == .phone {
                            ButtonLabel(text: String("Sable"), icon: "arrow.up.right.square")
                        } else {
                            ButtonLabel(text: LocalizedStringKey("Open \("Sable")"), icon: "arrow.up.right.square")
                        }
                    }
                    .modifier(MediaPreviewActionModifier())
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else {
                Spacer()
                    .modifier(MediaPreviewActionSpacerModifier())
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        renderRow(
            label,
            Text(value).foregroundStyle(.primary)
        )
    }

    func renderRow<V: View>(_ label: LocalizedStringKey, _ value: V) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
            Spacer()

            value
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    func parseDate(_ string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }

        return nil
    }

    func formatDate(_ date: Date) -> String {
        date.formatted(date: .long, time: .shortened)
    }

    func sableInstalled() -> Bool {
        #if os(macOS)
            return false
        #else
            return UIApplication.shared.canOpenURL(URL(string: "sable://open")!)
        #endif
    }
}
