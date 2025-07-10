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
                tagsField

                Toggle("Season Folders", isOn: $series.seasonFolder)
                    .tint(settings.theme.safeTint)
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
    
    var tagsField: some View {
        Menu {
            ForEach(instance.tags) { tag in
                Button {
                    if series.tags.contains(tag.id) {
                        series.tags.removeAll { $0 == tag.id }
                    } else {
                        series.tags.append(tag.id)
                    }
                } label: {
                    HStack {
                        Text(tag.label)
                        if series.tags.contains(tag.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(series.tags.isEmpty ? "Optional Tags".localizedCapitalized : instance.tags.filter { series.tags.contains($0.id) }.map { $0.label }.joined(separator: ", "))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .tint(.secondary)
    }

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
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series-lookup")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    return SeriesForm(
        series: Binding(get: { item }, set: { _ in })
    )
        .withSonarrInstance(series: series)
        .withAppState()
}

#Preview("Existing") {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    return SeriesForm(
        series: Binding(get: { item }, set: { _ in })
    )
        .withSonarrInstance(series: series)
        .withAppState()
}
