import SwiftUI

struct MovieReleaseRow: View {
    var release: MovieRelease

    @State private var isShowingPopover = false

    var body: some View {
        linesStack
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingPopover = true
            }
            .sheet(isPresented: $isShowingPopover) {
                MovieReleaseSheet(release: release)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
    }

    var linesStack: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Text(release.title.replacingOccurrences(of: ".", with: " "))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            let secondaryOpacity = 0.65

            Group {
                HStack(spacing: 6) {
                    Text(release.qualityLabel)
                    Bullet()
                    Text(release.sizeLabel)
                    Bullet()
                    Text(release.ageLabel)
                }
                .opacity(secondaryOpacity)
                .lineLimit(1)

                HStack(spacing: 6) {
                    Text(release.typeLabel)
                        .foregroundStyle(peerColor)

                    Group {
                        Bullet()
                        Text(release.indexerLabel)
                    }.opacity(secondaryOpacity)

                    Spacer()

                    releaseIcon
                }
                .lineLimit(1)
            }
            .font(.subheadline)
        }
    }

    var releaseIcon: some View {
        Group {
            if release.isFreeleech {
                Image(systemName: "f.square")
            } else if !release.indexerFlags.isEmpty {
                Image(systemName: "flag")
            }

            if release.rejected {
                Image(systemName: "exclamationmark.triangle")
            }
        }
        .symbolVariant(.fill)
        .imageScale(.medium)
        .foregroundStyle(.secondary)
    }

    var peerColor: any ShapeStyle {
        switch release.seeders ?? 0 {
        case 50...: .green
        case 10..<50: .blue
        case 1..<10: .orange
        default: .red
        }
    }
}
