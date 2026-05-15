//
//  ArtistReleasesView.swift
//  Ruddarr
//
//  Created by Lukas McDiarmid on 10/5/2026.
//

import SwiftUI

struct ArtistReleaseView: View {
    @Binding var artist: Artist
    @Binding var release: Album
    var albumId: Album.ID?
    var trackFileId: TrackFile.ID?

    @State private var releases: [ArtistRelease] = []
    @State private var fetched: (Artist.ID?, Album.ID?, TrackFile.ID?) = (nil, nil, nil)
    @State private var selectedRelease: SeriesRelease?

    @AppStorage("artistReleaseSort", store: dependencies.store) private var sort: ArtistReleaseSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        Divider()
    }
}
