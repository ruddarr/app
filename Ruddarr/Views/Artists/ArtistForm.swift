import SwiftUI

struct ArtistForm: View {
    @Binding var artist: Artist

    @EnvironmentObject var settings: AppSettings
    @Environment(LidarrInstance.self) private var instance

    @Environment(\.deviceType) private var deviceType

    @State private var defaultsSet = false
    @State private var showingConfirmation = false
    @State private var addOptions = ArtistAddOptions(monitor: .none)

    @AppStorage("artistDefaults", store: dependencies.store) var artistDefaults: ArtistDefaults = .init()

    var body: some View {
        Form {
            Section {
                if artist.exists {
                    Toggle("Monitored", isOn: $artist.monitored)
                        .tint(settings.theme.safeTint)

                    Toggle("Monitor New Releases", isOn: Binding(
                        get: { artist.monitorNewItems == .all },
                        set: { value in artist.monitorNewItems = value ? .all : ArtistMonitorNewItems.none })
                    )
                    .tint(settings.theme.safeTint)
                } else {
                    monitoringField
                }

                qualityProfileField
                metadataProfileField

                if !instance.tags.isEmpty {
                    tagsField
                }
            }

            if instance.rootFolders.count > 1 {
                rootFolderField
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectDefaultValues()
        }
    }

    var monitoringField: some View {
        Picker(selection: $addOptions.monitor) {
            ForEach(ArtistMonitorType.allCases) { type in
                if ![.unknown, .latest].contains(type) {
                    Text(type.label)
                }
            }
        } label: {
            Text("Monitor", comment: "Label of picker of what to monitor (movie, collection, episodes, etc.)")
        }
        .tint(.secondary)
        .onChange(of: addOptions.monitor, initial: true) {
            artist.addOptions?.monitor = addOptions.monitor
        }
    }

    var qualityProfileField: some View {
        Picker(selection: $artist.qualityProfileId) {
            ForEach(instance.qualityProfiles) { profile in
                Text(profile.name).tag(Optional.some(profile.id))
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                Text("Quality Profile")
                Text("Quality", comment: "Short version of Quality Profile")
            }
        }
        .tint(.secondary)
    }

    var metadataProfileField: some View {
        Picker(selection: $artist.metadataProfileId) {
            ForEach(instance.metadataProfiles) { profile in
                Text(profile.name).tag(Optional.some(profile.id))
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                Text("Metadata Profile")
                Text("Metadata", comment: "Short version of Metadata Profile")
            }
        }
        .tint(.secondary)
    }

#if os(macOS)
    var tagsField: some View {
        LabeledContent("Tags") {
            TagMenu(selected: tags(), tags: instance.tags)
        }
    }
#else
    var tagsField: some View {
        NavigationLink {
            TagList(selected: tags(), tags: instance.tags)
        } label: {
            LabeledContent("Tags") {
                Text(artist.tags.isEmpty ? "None" : "\(artist.tags.count) Tag")
            }
        }
    }
#endif

    var rootFolderField: some View {
        Picker("Root Folder", selection: $artist.rootFolderPath) {
            ForEach(instance.rootFolders) { folder in
                Text(folder.label).tag(folder.path)
            }
        }
        .pickerStyle(.inline)
        .tint(settings.theme.tint)
        .accentColor(settings.theme.tint) // `.tint()` is broken on inline pickers
    }

    func selectDefaultValues() {
        guard !defaultsSet else { return }
        defaultsSet = true

        if !artist.exists {
            addOptions.monitor = artistDefaults.monitor

            artist.addOptions = addOptions
            artist.monitorNewItems = nil
            artist.rootFolderPath = artistDefaults.rootFolder
            artist.qualityProfileId = artistDefaults.qualityProfile
            artist.metadataProfileId = artistDefaults.metadataProfile
        }

        if !instance.qualityProfiles.contains(where: {
            $0.id == artist.qualityProfileId
        }) {
            artist.qualityProfileId = instance.qualityProfiles.first?.id ?? 0
        }

        if !instance.metadataProfiles.contains(where: {
            $0.id == artist.metadataProfileId
        }) {
            artist.metadataProfileId = instance.metadataProfiles.first?.id ?? 0
        }

        // remove trailing slashes
        artist.rootFolderPath = artist.rootFolderPath?.untrailingSlashIt

        if !instance.rootFolders.contains(where: {
            $0.path?.untrailingSlashIt == artist.rootFolderPath
        }) {
            artist.rootFolderPath = instance.rootFolders.first?.path ?? ""
        }
    }

    func tags() -> Binding<Set<Tag.ID>> {
        Binding(
            get: { Set(artist.tags) },
            set: { artist.tags = Array($0) }
        )
    }
}

#Preview {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let item = artists.first(where: { $0.mbId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]

    NavigationStack {
        ArtistForm(
            artist: Binding(get: { item }, set: { _ in })
        )
    }
    .withLidarrInstance(artists: artists)
    .withAppState()
}

#Preview("Existing") {
    let artists: [Artist] = PreviewData.load(name: "artists")
    let item = artists.first(where: { $0.mbId == "3fd78e94-efeb-43a1-bc19-ad2dd1afbd5a" }) ?? artists[0]

    NavigationStack {
        ArtistForm(
            artist: Binding(get: { item }, set: { _ in })
        )
    }
    .withLidarrInstance(artists: artists)
    .withAppState()
}
