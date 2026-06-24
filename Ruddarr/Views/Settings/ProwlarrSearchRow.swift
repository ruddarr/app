import SwiftUI

struct ProwlarrSearchRow: View {
    let release: ProwlarrRelease

    @EnvironmentObject var settings: AppSettings

    var body: some View {
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

    var secondRow: some View {
        HStack(spacing: 6) {
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
                Text(release.indexerLabel)
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .lineLimit(1)
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
    let releases: [ProwlarrRelease] = PreviewData.load(name: "prowlarr-search")

    List {
        ForEach(releases) { release in
            ProwlarrSearchRow(release: release)
        }
    }
    .listStyle(.inset)
    .withAppState()
}
