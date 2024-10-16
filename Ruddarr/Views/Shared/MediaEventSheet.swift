import SwiftUI

struct MediaEventSheet: View {
    var event: MediaHistoryEvent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            VStack(alignment: .leading) {
                Text(event.eventType.title)
                    .font(.title3.bold())
                    .padding(.trailing, 25)

                Text(formatDate(event.date))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                Text(event.description)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom)

                if event.eventType == .grabbed {
                    grabbedDetails
                }

                Spacer()
            }
            .viewPadding(.horizontal)
            .padding(.top)
        }
    }

    var grabbedDetails: some View {
        VStack(spacing: 6) {
            row("Source", event.data("releaseSource") ?? "--")
            Divider()
            row("Match Type", event.data("movieMatchType") ?? "--")

            if let string = event.data("publishedDate"), let date = parseDate(string) {
                Divider()
                row("Published", formatDate(date))
            }

            if let string = event.data("nzbInfoUrl"), let url = URL(string: string), let domain = url.host {
                let link = Link(domain, destination: url).contextMenu {
                    LinkContextMenu(url)
                } preview: {
                    Text(url.absoluteString).padding()
                }

                Divider()
                renderRow("Link", link)
            }

            if let flags = event.indexerFlagsLabel {
                Divider()
                row("Flags", flags)
            }

            if let score = event.scoreLabel {
                Divider()
                row("Score", score)
            }

            if let formats = event.customFormats, !formats.isEmpty {
                Divider()
                row("Custom Formats", formats.map { $0.label }.formattedList())
            }

            if let group = event.data("releaseGroup") {
                Divider()
                row("Release Group", group)
            }
        }
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
}

#Preview("File") {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 295 }) ?? movies[0]

    return MediaFileSheet(file: movie.movieFile!)
}

#Preview("Event") {
    let events: [MediaHistoryEvent] = PreviewData.load(name: "movie-history")

    return MediaEventSheet(event: events[1])
}
