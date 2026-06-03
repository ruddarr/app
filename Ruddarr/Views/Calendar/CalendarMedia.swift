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
                        .foregroundStyle(shouldFade ? .secondary : .primary)

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
            .opacity(shouldFade ? 0.5 : 1)
            .background(.card.opacity(shouldFade ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture {
                dependencies.router.presentMovie(movie)
            }
    }

    var shouldFade: Bool {
        !movie.monitored && !movie.isDownloaded
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
                    .foregroundStyle(shouldFade ? .secondary : .primary)

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
        .opacity(shouldFade ? 0.5 : 1)
        .background(.card.opacity(shouldFade ? 0.6 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            dependencies.router.presentEpisode(episode, grouped: isGrouped)
        }
    }

    var shouldFade: Bool {
        !episode.isDownloaded
            && (!episode.monitored || episode.series?.monitored == false)
    }

    @ViewBuilder
    var tag: some View {
        if isGrouped, let hidden = episode.calendarGroupCount {
            Text(String(localized: "+\(hidden - 1) more..."))
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        } else if episode.isSpecial {
            Text(episode.specialLabel)
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        } else if let finale = episode.finaleType {
            Text(finale.label)
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        } else if episode.isPremiere {
            Text(episode.premiereLabel)
                .font(.caption)
                .foregroundStyle(settings.theme.tint)
        }
    }

    @ViewBuilder
    var statusIcon: some View {
        if episode.isDownloaded {
            Image(systemName: "checkmark").symbolVariant(.circle.fill)
        } else if !episode.monitored || episode.series?.monitored == false {
            Image(systemName: "bookmark").symbolVariant(.slash)
        } else if !episode.hasAired {
            Image(systemName: "clock")
        } else if episode.monitored {
            Image(systemName: "xmark").symbolVariant(.circle)
        }
    }

    var isGrouped: Bool {
        (episode.calendarGroupCount ?? 0) > 2
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
