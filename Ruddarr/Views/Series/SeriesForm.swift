import SwiftUI

struct SeriesForm: View {
    @Binding var series: Series

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.deviceType) private var deviceType

    @State private var showingConfirmation = false
    @State private var addOptions = SeriesAddOptions(monitor: .none)

    @AppStorage("seriesDefaults", store: dependencies.store) var seriesDefaults: SeriesDefaults = .init()

    var body: some View {
        Form {
            Section {
                if series.exists {
                    Toggle("Monitored", isOn: $series.monitored)
                        .tint(settings.theme.safeTint)

                    Toggle("Monitor New Seasons", isOn: Binding(
                        get: { series.monitorNewItems == .all },
                        set: { value in series.monitorNewItems = value ? .all : SeriesMonitorNewItems.none })
                    )
                        .tint(settings.theme.safeTint)
                } else {
                    monitoringField
                }

                qualityProfileField
                typeField

                Toggle("Season Folders", isOn: $series.seasonFolder)
                    .tint(settings.theme.safeTint)

                tagsField
            }

            if instance.rootFolders.count > 1 {
                rootFolderField
            }
        }
        .onAppear {
            selectDefaultValues()
        }
    }

    var monitoringField: some View {
        Picker(selection: $addOptions.monitor) {
            ForEach(SeriesMonitorType.allCases) { type in
                if ![.unknown, .latestSeason, .skip].contains(type) {
                    Text(type.label)
                }
            }
        } label: {
            Text("Monitor", comment: "Label of picker of what to monitor (movie, collection, etc.)")
        }
        .tint(.secondary)
        .onChange(of: addOptions.monitor, initial: true) {
            series.addOptions?.monitor = addOptions.monitor
        }
    }

    var qualityProfileField: some View {
        Picker(selection: $series.qualityProfileId) {
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

    var typeField: some View {
        Picker(selection: $series.seriesType) {
            ForEach(SeriesType.allCases) { type in
                Text(type.label)
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                Text("Series Type")
                Text("Type", comment: "Short version of Series Type")
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
            LabeledContent {
                Text(series.tags.isEmpty ? "None" : "\(series.tags.count) Tag")
            } label: {
                Text("Tags")
            }
        }
    }
#endif

    var rootFolderField: some View {
        Picker("Root Folder", selection: $series.rootFolderPath) {
            ForEach(instance.rootFolders) { folder in
                Text(folder.label).tag(folder.path)
            }
        }
        .pickerStyle(.inline)
        .tint(settings.theme.tint)
        .accentColor(settings.theme.tint) // `.tint()` is broken on inline pickers
    }

    func selectDefaultValues() {
        if !series.exists {
            addOptions.monitor = seriesDefaults.monitor

            series.addOptions = addOptions
            series.monitorNewItems = nil
            series.rootFolderPath = seriesDefaults.rootFolder
            series.seasonFolder = seriesDefaults.seasonFolder
            series.qualityProfileId = seriesDefaults.qualityProfile
        }

        if !instance.qualityProfiles.contains(where: {
            $0.id == series.qualityProfileId
        }) {
            series.qualityProfileId = instance.qualityProfiles.first?.id ?? 0
        }

        // remove trailing slashes
        series.rootFolderPath = series.rootFolderPath?.untrailingSlashIt

        if !instance.rootFolders.contains(where: {
            $0.path?.untrailingSlashIt == series.rootFolderPath
        }) {
            series.rootFolderPath = instance.rootFolders.first?.path ?? ""
        }
    }

    func tags() -> Binding<Set<Tag.ID>> {
        Binding(
            get: { Set(series.tags) },
            set: { series.tags = Array($0) }
        )
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series-lookup")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    NavigationStack {
        SeriesForm(
            series: Binding(get: { item }, set: { _ in })
        )
    }
    .withSonarrInstance(series: series)
    .withAppState()
}

#Preview("Existing") {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    NavigationStack {
        SeriesForm(
            series: Binding(get: { item }, set: { _ in })
        )
    }
    .withSonarrInstance(series: series)
    .withAppState()
}
