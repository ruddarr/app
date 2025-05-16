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
                let deeplink = String(
                    format: "ruddarr://movies/open/%d?instance=%@",
                    movie.id,
                    movie.instanceId!.uuidString
                )

                try? QuickActions.Deeplink(url: URL(string: deeplink)!)()
            }
    }

    @ViewBuilder
    var statusIcon: some View {
        if movie.isDownloaded {
            Image(systemName: "checkmark").symbolVariant(.circle.fill)
        } else if !movie.monitored {
            Image(systemName: "bookmark").symbolVariant(.slash)
        } else if movie.isWaiting {
            Image(systemName: "clock")
        } else if movie.monitored {
            Image(systemName: "xmark").symbolVariant(.circle)
        }
    }
}

struct CalendarEpisode: View {
    var episode: Episode

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(episode.series?.title ?? "Unknown")
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
        .onTapGesture {
            let deeplink = String(
                format: "ruddarr://series/open/%d?season=%d&episode=%d&instance=%@",
                episode.seriesId,
                episode.seasonNumber,
                episode.episodeNumber,
                episode.instanceId!.uuidString
            )

            try? QuickActions.Deeplink(url: URL(string: deeplink)!)()
        }
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

        if let hidden = episode.calendarGroupCount, hidden > 1 {
            Text(String(localized: "+\(hidden - 1) more..."))
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        }
    }

    @ViewBuilder
    var statusIcon: some View {
        if episode.isDownloaded {
            Image(systemName: "checkmark").symbolVariant(.circle.fill)
        } else if !episode.monitored {
            Image(systemName: "bookmark").symbolVariant(.slash)
        } else if !episode.hasAired {
            Image(systemName: "clock")
        } else if episode.monitored {
            Image(systemName: "xmark").symbolVariant(.circle)
        }
    }
}

enum CalendarMediaType: CaseIterable {
    case all
    case movies
    case series

    var label: some View {
        switch self {
        case .all: Label(String(localized: "Everything", comment: "Movies and series filter option"), systemImage: "rectangle.stack")
        case .movies: Label(String(localized: "Movies"), systemImage: "film")
        case .series: Label(String(localized: "Series"), systemImage: "tv")
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}
