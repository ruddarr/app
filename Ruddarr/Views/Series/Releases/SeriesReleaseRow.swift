import SwiftUI

struct SeriesReleaseRow: View {
    var release: SeriesRelease
    var series: Series

    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch settings.releaseLayout {
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

            secondRow
            thirdRow
        }
        .contentShape(Rectangle())
    }

    var detailedRow: some View {
        VStack(alignment: .leading) {
            if !flagLabels.isEmpty {
                Text(flagLabels.joined(separator: "  "))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }

            Text(release.title.breakable())
                .font(.headline)
                .fontWeight(.semibold)

            qualityRow
            sourceRow

            CustomFormats(release.formatLabels)
        }
        .contentShape(Rectangle())
    }

    var qualityRow: some View {
        HStack(spacing: 6) {
            Text(release.qualityLabel)
            Bullet()
            Text(release.sizeLabel)

            if let bitrate = release.bitrateLabel(series.runtime * release.episodeCount) {
                Bullet()
                Text(bitrate)
            }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .font(.subheadline)
    }

    var sourceRow: some View {
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
    }

    var secondRow: some View {
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
    }

    var thirdRow: some View {
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

            if release.hasNonFreeleechFlags {
                Image(systemName: "flag.square")
            }

            if release.rejected {
                Image(systemName: "exclamationmark.square")
            }
        }
        .symbolVariant(.fill)
        .imageScale(.medium)
        .foregroundStyle(.secondary)
    }

    var flagLabels: [String] {
        var labels = release.flagLabels

        if release.rejected {
            labels.insert(String(localized: "Rejected", comment: "Rejected release"), at: 0)
        }

        return labels
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
