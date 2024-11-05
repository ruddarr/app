import SwiftUI

struct MediaHistoryItem: View {
    var event: MediaHistoryEvent

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GroupBox {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(event.quality.quality.label)
                    Bullet()
                    Text(event.languageLabel)

                    if let indexer = event.indexerLabel {
                        Bullet()
                        Text(indexer)
                    }

                    Spacer()
                    Text(date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.quality.quality.label)
                    Bullet()
                    Text(event.languageLabel)

                    Spacer()
                    Text(date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        } label: {
            Text(event.eventType.label)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(settings.theme.tint)

            Text(title ?? "--")
        }
    }

    var title: String? {
        guard let title = event.sourceTitle else { return nil }
        guard title.hasPrefix("/") else { return title }
        return title.components(separatedBy: "/").last
    }

    var date: String {
        if abs(event.date.timeIntervalSinceNow) < 60 {
            return formatAge(0)
        }

        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

        if event.date > twoWeeksAgo {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .numeric
            formatter.unitsStyle = .abbreviated

            return formatter.localizedString(for: event.date, relativeTo: Date())
        }

        if Calendar.current.isDate(event.date, equalTo: .now, toGranularity: .year) {
            return event.date.formatted(.dateTime.day().month())
        }

        return event.date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .withAppState()
    }
}
