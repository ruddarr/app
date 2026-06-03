import SwiftUI

struct CalendarMovie: View {
    var date: Date
    var movie: Movie
    var downloadProgress: Float?

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

                    status
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
                let deeplink = String(
                    format: "ruddarr://movies/open/%d?instance=%@",
                    movie.id,
                    movie.instanceId!.uuidString
                )

                try? QuickActions.Deeplink(url: URL(string: deeplink)!)()
            }
    }

    var shouldFade: Bool {
        !movie.monitored && !movie.isDownloaded
    }

    @ViewBuilder
    var status: some View {
        if let downloadProgress {
            CalendarDownloadProgress(progress: downloadProgress)
        } else {
            statusIcon
                .font(.subheadline)
                .imageScale(.small)
                .foregroundStyle(.secondary)
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
    var downloadProgress: Float?

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

                status
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
    var status: some View {
        if let downloadProgress {
            CalendarDownloadProgress(progress: downloadProgress)
        } else {
            statusIcon
                .foregroundStyle(.secondary)
                .imageScale(.small)
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

private struct CalendarDownloadProgress: View {
    var progress: Float

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.28), lineWidth: 2)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(settings.theme.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("Downloading")
        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
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
