import SwiftUI

struct ArtistEditView: View {
    @Binding var artist: Artist

    init(artist: Binding<Artist>) {
        self._artist = artist
        self._unmodifiedArtist = State(initialValue: artist.wrappedValue)
    }

    @Environment(LidarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss

    @State private var showConfirmation: Bool = false
    @State private var savedChanges: Bool = false
    @State private var unmodifiedArtist: Artist

    var body: some View {
        ArtistForm(artist: $artist)
            #if os(iOS)
                .padding(.top, -20)
            #endif
            .navigationTitle(artist.title)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarSaveButton
            }
            .onDisappear {
                if !savedChanges {
                    undoArtistChanges()
                }
            }
            .alert(
                isPresented: instance.artists.errorBinding,
                error: instance.artists.error
            ) { _ in
                Button("OK") { instance.artists.error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .alert(
                "Move the artist files to \"\(artist.rootFolderPath ?? "")\"?",
                isPresented: $showConfirmation
            ) {
                Button("Move Files", role: .destructive) {
                    Task { await updateArtist(moveFiles: true) }
                }
                Button("No", role: .confirm) {
                    Task { await updateArtist() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .tint(nil)
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                if artist.exists && hasRootFolderChanged() {
                    showConfirmation = true
                } else {
                    Task { await updateArtist() }
                }
            } label: {
                if instance.artists.isWorking {
                    ButtonProgressView()
                } else {
                    Label("Save", systemImage: "checkmark")
                        .hideIconOnMac()
                }
            }
            .prominentGlassButtonStyle(!instance.artists.isWorking)
        }
    }

    func hasRootFolderChanged() -> Bool {
        artist.rootFolderPath?.untrailingSlashIt != unmodifiedArtist.rootFolderPath?.untrailingSlashIt
    }

    func updateArtist(moveFiles: Bool = false) async {
        _ = await instance.artists.update(artist, moveFiles: moveFiles)

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        savedChanges = true

        dismiss()
    }

    func undoArtistChanges() {
        artist.monitored = unmodifiedArtist.monitored
        artist.qualityProfileId = unmodifiedArtist.qualityProfileId
        artist.metadataProfileId = unmodifiedArtist.metadataProfileId
        artist.rootFolderPath = unmodifiedArtist.rootFolderPath
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let item = artists.first(where: { $0.id == 159 }) ?? artists[0]

    dependencies.router.selectedTab = .artists
    dependencies.router.artistsPath.append(ArtistsPath.artist(item.id))
    dependencies.router.artistsPath.append(ArtistsPath.edit(item.id))

    return ContentView()
        .withLidarrInstance(artists: artists)
        .withAppState()
}
