import SwiftUI

struct CalendarMovie: View {
    var date: Date
    var movie: Movie

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Group {
            if settings.richCalendarDisplay {
                richContent
            } else {
                classicContent
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, settings.richCalendarDisplay ? 8 : 12)
        .frame(maxWidth: .infinity)
        .opacity(shouldFade ? 0.5 : 1)
        .background(.card.opacity(shouldFade ? 0.6 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            let deeplink = String(
                format: "ruddarr://movies/open/%d?instance=%@",
                movie.id,
                movie.instanceId!.uuidString
            )

            try? QuickActions.Deeplink(url: URL(string: deeplink)!)()
        }
    }

    var richContent: some View {
        HStack(alignment: .center, spacing: 10) {
            CalendarPoster(url: movie.remotePoster, title: movie.title)

            VStack(alignment: .leading, spacing: 3) {
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

            Spacer(minLength: 0)
        }
    }

    var classicContent: some View {
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
        Group {
            if settings.richCalendarDisplay {
                richContent
            } else {
                classicContent
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, settings.richCalendarDisplay ? 8 : 12)
        .frame(maxWidth: .infinity)
        .opacity(shouldFade ? 0.5 : 1)
        .background(.card.opacity(shouldFade ? 0.6 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            var deeplink = String(
                format: "ruddarr://series/open/%d?season=%d&instance=%@",
                episode.seriesId,
                episode.seasonNumber,
                episode.instanceId!.uuidString
            )

            if !isGrouped {
                deeplink.append("&episode=\(episode.episodeNumber)")
            }

            try? QuickActions.Deeplink(url: URL(string: deeplink)!)()
        }
    }

    var richContent: some View {
        HStack(alignment: .center, spacing: 10) {
            CalendarPoster(url: episode.series?.remotePoster, title: episode.series?.title)

            VStack(alignment: .leading, spacing: 3) {
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

            Spacer(minLength: 0)
        }
    }

    var classicContent: some View {
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

private struct CalendarPoster: View {
    var url: String?
    var title: String?

    var body: some View {
        CachedAsyncImage(.poster, url, placeholder: title)
            .aspectRatio(CGSize(width: 150, height: 225), contentMode: .fill)
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
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
