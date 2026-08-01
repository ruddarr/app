import SwiftUI

struct SeriesReleaseRow: View {
    var release: SeriesRelease
    var series: Series

    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch settings.releases {
        case .compact: compactRow
        case .detailed: detailedRow
        }
    }

    var compactRow: some View {
        VStack(alignment: .leading) {
            Text(release.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)
                Bullet()
                Text(release.ageLabel)
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .font(.subheadline)

            HStack(spacing: 6) {
                Text(release.typeLabel)
                    .foregroundStyle(peerColor)
                    .truncationMode(.head)

                Group {
                    Bullet()
                    Text(release.languageLabel)
                    Bullet()
                    Text(release.indexerLabel)
                }
                .foregroundStyle(.secondary)

                Spacer()

                releaseIcons
            }
            .lineLimit(1)
            .font(.subheadline)
        }
        .contentShape(Rectangle())
    }

    var detailedRow: some View {
        // swiftlint:disable:next closure_body_length
        VStack(alignment: .leading) {
            Text(release.title.breakable(minimumTail: 10))
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                Text(release.typeLabel)
                    .foregroundStyle(peerColor)
                    .truncationMode(.head)

                Group {
                    Bullet()
                    Text(release.languageLabel)
                    Bullet()
                    Text(release.ageLabel)
                    Bullet()
                    Text(release.indexerLabel)
                }
                .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .font(.subheadline)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)

                if let bitrate = release.bitrateLabel(series.runtime * release.episodeCount) {
                    Bullet()
                    Text(bitrate)
                }

                Spacer(minLength: 0)

                if !release.flagLabels.isEmpty || release.rejected {
                    releaseIcons
                }
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .font(.subheadline)

            CustomFormats(release.formatLabels)
        }
        .contentShape(Rectangle())
    }

    var releaseIcons: some View {
        HStack(spacing: 2) {
            if release.isFreeleech {
                Image(systemName: "f.square")
            }

            if release.isProper {
                Image(systemName: "p.square")
            }

            if release.isRepack {
                Image(systemName: "r.square")
            }

            if release.isInternal {
                Image(systemName: "i.square")
            }

            if release.isScene {
                Image(systemName: "s.square")
            }

            if release.isNuked {
                Image(systemName: "trash.square")
            }

            if release.hasOtherFlags {
                Image(systemName: "flag.square")
            }

            if release.rejected {
                Image(systemName: "exclamationmark.square")
                    .foregroundStyle(.orange)
            }
        }
        .symbolVariant(.fill)
        .imageScale(.medium)
        .foregroundStyle(.secondary)
        .font(.subheadline)
    }

    var peerColor: any ShapeStyle {
        guard release.isTorrent else { return .green }

        return switch release.seeders ?? 0 {
        case 50...: .green
        case 10..<50: .blue
        case 1..<10: .orange
        default: .red
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesPath.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesPath.releases(item.id, 2, nil)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
