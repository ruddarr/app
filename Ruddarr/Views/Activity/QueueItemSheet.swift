import SwiftUI

struct QueueItemSheet: View {
    var item: QueueItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            VStack(alignment: .leading) {
                Text(item.title ?? "Unknown")
                    .font(.title3.bold())
                    .padding(.trailing, 25)

                // TODO: size (gb)
                // TODO: status

//                Text(formatDate(item.added))
//                    .font(.footnote)
//                    .foregroundStyle(.secondary)
//                    .padding(.bottom, 12)

//                Text(item.description)
//                    .font(.callout)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.bottom)

                details

                Spacer()
            }
            .viewPadding(.horizontal)
            .padding(.top)
        }
    }

    @ViewBuilder
    var details: some View {
        VStack(spacing: 6) {
            row("Quality", item.quality.quality.name ?? "--")
            Divider()
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
