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

                    if item.trackedDownloadStatus != .ok {
                        GroupBox {
                            statusMessages
                        }
                        .padding(.bottom)
                    } else {
                        Text(item.title ?? "Unknown")
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom)
                    }

                    details

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

        Text(item.titleLabel)
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
        .padding(.bottom)
    }

    @ViewBuilder
    var statusMessages: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(item.statusMessages, id: \.self) { status in
                VStack(alignment: .leading) {
                    Text(status.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(status.messages, id: \.self) { message in
                        Text(message)
                            .font(.footnote)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var details: some View {
        VStack(spacing: 6) {
            row("Languages", item.languagesLabel ?? "--")

            if let score = item.scoreLabel {
                Divider()
                row("Score", score)
            }

            if !item.customFormats.isEmpty {
                Divider()
                row("Custom Formats", item.customFormats.map { $0.label }.formattedList())
            }

            if let indexer = item.indexer {
                Divider()
                row("Indexer", formatIndexer(indexer))
            }

            if let date = item.added {
                Divider()
                row("Added", date.formatted(date: .long, time: .shortened))
            }

            Divider()
            row("Protocol", item.type.label)

            Divider()
            row("Client", item.downloadClient ?? "--")
        }
    }

    func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        renderRow(label, Text(value).foregroundStyle(.primary))
    }

    func renderRow<V: View>(_ label: LocalizedStringKey, _ value: V) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
            Spacer()
            value
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
}
