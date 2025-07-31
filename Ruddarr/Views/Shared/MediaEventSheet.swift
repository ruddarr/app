import SwiftUI

struct MediaEventSheet: View {
    var event: MediaHistoryEvent
    var instanceId: Instance.ID?

    @EnvironmentObject var settings: AppSettings

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading) {
                    if let instanceId, let instance = settings.instanceById(instanceId) {
                        Text(instance.label)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(1.1)
                            .foregroundStyle(settings.theme.tint)
                    }

                    Text(event.eventType.title)
                        .font(.title2.bold())
                        .kerning(-0.5)
                        .padding(.trailing, 40)

                    Text(formatDate(event.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if event.eventType == .grabbed {
                        CustomFormats(tags())
                    }

                    Text(event.description)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.top, 12)
                        .padding(.bottom)

                    if event.eventType == .grabbed {
                        grabbedDetails
                    }

                    Spacer()
                    Spacer()
                }
                .padding(.top)
                .viewPadding(.horizontal)
            }
        }
    }

    var grabbedDetails: some View {
        let rows: [AnyView] = grabbedData()

        return VStack(spacing: 6) {
            ForEach(0..<rows.count, id: \.self) { index in
                rows[index]

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
    }

    func grabbedData() -> [AnyView] {
        var data: [AnyView] = []

        if let indexer = event.indexerLabel {
            data.append(row(String(localized: "Indexer"), indexer))
        }

        if let flags = event.indexerFlagsLabel {
            data.append(row(String(localized: "Flags", comment: "Indexer flags"), flags))
        }

        if let releaseSource = event.data("releaseSource") {
            data.append(row(String(localized: "Source", comment: "Release source"), releaseSource))
        }

        if let movieMatchType = event.data("movieMatchType") {
            data.append(row(String(localized: "Match Type", comment: "Release match type"), movieMatchType))
        }

        if let seriesMatchType = event.data("seriesMatchType") {
            data.append(row(String(localized: "Match Type", comment: "Release match type"), seriesMatchType))
        }

        if let releaseType = event.data("releaseType") {
            data.append(row(String(localized: "Release Type"), releaseType))
        }

        if let group = event.data("releaseGroup") {
            data.append(row(String(localized: "Release Group"), group))
        }

        if let string = event.data("ageMinutes"), let minutes = Float(string) {
            data.append(row(String(localized: "Age"), formatAge(minutes)))
        }

        if let size = event.data("size"), let bytes = Int(size) {
            data.append(row(String(localized: "File Size"), formatBytes(bytes)))
        }

        if let string = event.data("publishedDate"), let date = parseDate(string) {
            data.append(row(String(localized: "Published", comment: "Release publish date"), formatDate(date)))
        }

        if let string = event.data("nzbInfoUrl"),
           let url = URL(string: string),
           let domain = url.host
        {
            data.append(row(String(localized: "Link"), Link(domain, destination: url).contextMenu {
                LinkContextMenu(url)
            } preview: {
                Text(url.absoluteString).padding()
            }))
        }

        return data
    }

    func tags() -> [String] {
        var tags: [String] = []

        if let score = event.scoreLabel {
            tags.append(score)
        }

        if let formats = event.customFormats, !formats.isEmpty {
            tags.append(contentsOf: formats.map { $0.label })
        }

        return tags
    }

    func row(_ label: String, _ value: String) -> AnyView {
        row(label, Text(value).foregroundStyle(.primary))
    }

    func row<V: View>(_ label: String, _ value: V) -> AnyView {
        AnyView(
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
        )
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

    return MediaFileSheet(file: movie.movieFile!, runtime: movie.runtime)
}

#Preview("Event") {
    let events: [MediaHistoryEvent] = PreviewData.load(name: "movie-history")

    return MediaEventSheet(event: events[2])
}
