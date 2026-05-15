//
//  ArtistPreviewView.swift
//  Ruddarr
//
//  Created by Lukas McDiarmid on 10/5/2026.
//

import SwiftUI

struct ArtistPreviewView: View {
    @State var artist: Artist
    @State var releases: [Album] = []

    @State private var presentingForm: Bool = false

    @EnvironmentObject var settings: AppSettings

    @Environment(LidarrInstance.self) private var instance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @AppStorage("artistSort", store: dependencies.store) var artistSort: ArtistSort = .init()
    @AppStorage("artistDefaults", store: dependencies.store) var artistDefaults: ArtistDefaults = .init()

    var body: some View {
        ScrollView {
            ArtistDetails(artist: $artist, albums: $releases)
                .padding(.top)
                .scenePadding(.horizontal)
                .environmentObject(settings)
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .alert(
            isPresented: instance.artists.errorBinding,
            error: instance.artists.error
        ) { _ in
            Button("OK") { instance.artists.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .tint(nil)
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                ArtistForm(artist: $artist)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
                    #if os(iOS)
                        .padding(.top, -25)
                    #endif
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
            .presentationBackground(.sheetBackground)
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presentingForm = false
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .hideIconOnMac()
            }
            .tint(.primary)
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Artist", systemImage: "plus") {
                presentingForm = true
            }
            .hideIconOnMac()
            .buttonStyle(.glassProminent)
            .disabled(presentingForm)
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await addArtist()
                }
            } label: {
                if instance.artists.isWorking {
                    ButtonProgressView()
                } else {
                    Label("Add Artist", systemImage: "checkmark")
                        .hideIconOnMac()
                }
            }
            .prominentGlassButtonStyle(!instance.artists.isWorking)
            .disabled(instance.artists.isWorking)
        }
    }

    func addArtist() async {
        artistDefaults = .init(from: artist)

        guard await instance.artists.add(artist) else {
            leaveBreadcrumb(.error, category: "view.artists.preview", message: "Failed to add artist", data: ["error": instance.artists.error ?? ""])

            return
        }

        guard let addedArtist = instance.artists.byMbId(artist.mbId) else {
            fatalError("Failed to locate added artist by Musicbrainz id")
        }

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        presentingForm = false
        artistSort.filter = .all

        let artistsPath = ArtistsPath.artist(addedArtist.id)

        if !dependencies.router.artistsPath.isEmpty {
            dependencies.router.artistsPath.removeLast()
        }

        try? await Task.sleep(for: .milliseconds(50))
        dependencies.router.artistsPath.append(artistsPath)

        Telemetry.record(.artistAdded, attributes: [
            "mbid": artist.mbId ?? "",
            "tadb": artist.tadbId ?? 0,
            "discogs": artist.discogsId ?? 0,
            "allMusic": artist.allMusicId ?? 0
        ])

        maybeAskForReview()
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let item = artists.first(where: { $0.mbId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]

    dependencies.router.selectedTab = .artists

    dependencies.router.artistsPath.append(
        ArtistsPath.preview(
            try? JSONEncoder().encode(item)
        )
    )

    return ContentView()
        .withLidarrInstance(artists: artists)
        .withAppState()
}
