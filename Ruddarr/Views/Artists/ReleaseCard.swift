import SwiftUI

struct ReleaseCard: View {
    @Binding var artist: Artist
    @Binding var album: Album
    var albums: [Album] = []
//    var album: Album

    @State private var isWorking: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(LidarrInstance.self) private var instance

    // TODO: What if I make these cards to match the whole appeal of album covers?
    var body: some View {
        LabeledGroupBox {
            HStack(spacing: 12) {
                Text(album.title)
                    .fontWeight(.medium)

                if let progress = album.progressLabel {
                    Text(progress)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await toggle()
                    }
                } label: {
                    if isWorking {
                        ButtonProgressView(tint: .secondary).offset(x: 1.5)
                    } else {
                        Image(systemName: "bookmark")
                            .symbolVariant(album.monitored ? .fill : .none)
                            .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
                    }
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().padding(18))
                .allowsHitTesting(!instance.albums.isWorking)
            }
        }
    }

    func toggle() async {
        guard !isWorking else { return }

        album.monitored.toggle()

        isWorking = true

        guard await instance.albums.push(album) else {
            isWorking = false
            return
        }

        isWorking = false

        dependencies.toast.show(
            album.monitored ? .monitored : .unmonitored
        )

        await instance.albums.fetch(artist)
    }
}
