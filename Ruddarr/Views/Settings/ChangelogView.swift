import SwiftUI

struct ChangelogView: View {
    private let releases = ChangelogParser.all

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(releases) { release in
                    card(release)
                }
            }
            .padding()
        }
        .navigationTitle("Release Notes")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func card(_ release: ChangelogRelease) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(verbatim: release.version)
                    .font(.title2.bold())

                Spacer()

                Text(release.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, -2)

            if let note = release.note {
                Text(note.toMarkdown())
                    .font(.subheadline)
            }

            ForEach(release.sections) { section in
                sectionView(section)
            }
        }
        .textSelection(.enabled)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.card)
        )
    }

    private func sectionHeader(section: ChangelogSection) -> some View {
        Text(section.kind.rawValue.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(section.kind.color)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 5).fill(section.kind.color.opacity(0.1))
            )
    }

    private func sectionView(_ section: ChangelogSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(section: section)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(section.bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Bullet().font(.headline)

                        Text(bullet.toMarkdown())
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
        }
    }
}

private extension ChangelogKind {
    var color: Color {
        switch self {
        case .added: .green
        case .changed: .blue
        case .security: .orange
        default: .secondary
        }
    }
}

#Preview {
    NavigationStack {
        ChangelogView()
    }
}
