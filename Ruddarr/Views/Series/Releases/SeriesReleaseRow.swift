import SwiftUI

struct SeriesReleaseRow: View {
    var release: SeriesRelease

    @State private var isShowingPopover = false

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        linesStack
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingPopover = true
            }
            .sheet(isPresented: $isShowingPopover) {
//                SeriesReleaseSheet(release: release)
//                    .presentationDetents([.medium])
//                    .presentationDragIndicator(.hidden)
//                    .environment(instance)
//                    .environmentObject(settings)
            }
    }

    var linesStack: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Text(release.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            secondRow
            thirdRow
        }
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
        SeriesView.Path.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesView.Path.releases(item.id, 2, nil)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
