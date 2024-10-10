import SwiftUI

struct QueueItemSheet: View {
    var item: QueueItem

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

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
                    
                    if let sableURL = sable {
                        if item.downloadClient == "SABnzbd" {
                            openInSable
                        }
                    }

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
            .lineLimit(2)
            .padding(.trailing, 25)

        HStack(spacing: 6) {
            Text(item.quality.quality.label)
            Bullet()
            Text(formatBytes(Int(item.size)))
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }

    @ViewBuilder
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

    @ViewBuilder
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
    
    @ViewBuilder
    var openInSable: some View {
        Button {
            if let url = URL(string: "sable://open") {
                UIApplication.shared.open(url)
            }
        } label: {
            ButtonLabel(text: "Open in Sable", icon: "arrowshape.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
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
    
    var sable: String? {
        #if os(iOS)
            let url = "sable://open"

            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                return url
            }
        #endif

        return nil
    }
}
