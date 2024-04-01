import SwiftUI

struct CalendarMovie: View {
    var date: Date
    var movie: Movie

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center) {
                    Text(movie.title)
                        .font(.body)
                        .lineLimit(1)

                    Spacer()

                    statusIcon
                        .font(.subheadline)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }

                if let type = movie.releaseType(for: date) {
                    Text(type)
                        .font(.caption)
                        .foregroundStyle(settings.theme.tint)
                }
            }
        }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(.secondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                let instance = movie.instanceId!.uuidString
                let deeplink = URL(string: "ruddarr://movies/open/\(movie.id)?instance=\(instance)")
                try? QuickActions.Deeplink(url: deeplink!)()
            }
    }

    @ViewBuilder
    var statusIcon: some View {
        if movie.isDownloaded {
            Image(systemName: "checkmark")
                .symbolVariant(.circle.fill)
        } else if !movie.monitored {
            Image(systemName: "bookmark.slash")
        } else if movie.isWaiting {
            Image(systemName: "clock")
        } else if movie.monitored {
            Image(systemName: "xmark")
                .symbolVariant(.circle)
        }
    }
}

struct CalendarEpisode: View {
    var episode: Episode
    var seriesTitle: String

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(seriesTitle)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                if let airDate = episode.airDateUtc {
                    Text(airDate.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 6) {
                Text(episode.episodeLabel)

                if let title = episode.title {
                    Bullet()
                    Text(title).lineLimit(1)
                }

                Spacer()

                statusIcon
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)

            tag
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    var tag: some View {
        if episode.isSpecial {
            Text(episode.specialLabel)
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        }

        if let finale = episode.finaleType {
            Text(finale.label)
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        }

        if episode.isPremiere {
            Text(episode.premiereLabel)
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        }
    }

    @ViewBuilder
    var statusIcon: some View {
        if episode.isDownloaded {
            Image(systemName: "checkmark")
                .symbolVariant(.circle.fill)
        } else if !episode.monitored {
            Image(systemName: "bookmark.slash")
        } else if episode.isWaiting {
            Image(systemName: "clock")
        } else if episode.monitored {
            Image(systemName: "xmark")
                .symbolVariant(.circle)
        }
    }
}

enum CalendarMediaType: CaseIterable {
    case all
    case movies
    case series

    var label: some View {
        switch self {
        case .all: Label("Everything", systemImage: "rectangle.stack")
        case .movies: Label("Movies", systemImage: "film")
        case .series: Label("Series", systemImage: "tv")
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}
