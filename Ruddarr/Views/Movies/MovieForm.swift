import SwiftUI

struct MovieForm: View {
    @Binding var movie: Movie

    @Environment(AppSettings.self) private var settings
    @Environment(RadarrInstance.self) private var instance
    @Environment(\.deviceType) private var deviceType

    @State private var defaultsSet = false
    @State private var showingConfirmation = false
    @State private var addOptions = MovieAddOptions(monitor: .movieOnly)

    @AppStorage("movieDefaults", store: dependencies.store) var movieDefaults: MovieDefaults = .init()

    var body: some View {
        Form {
            Section {
                if movie.exists {
                    Toggle("Monitored", isOn: $movie.monitored)
                        .tint(settings.theme.safeTint)
                } else {
                    monitoringField
                }

                minimumAvailabilityField
                qualityProfileField

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

    var availabilities: [MovieStatus] = [
        .announced,
        .inCinemas,
        .released,
    ]

    @ViewBuilder
    var monitoringField: some View {
        if movie.exists {
            Toggle("Monitored", isOn: $movie.monitored)
                .tint(settings.theme.safeTint)
        } else {
            Picker(selection: $addOptions.monitor) {
                ForEach(MovieMonitorType.allCases) { type in
                    Text(type.label)
                }
            } label: {
                Text("Monitor", comment: "Label of picker of what to monitor (movie, collection, episodes, etc.)")
            }
            .tint(.secondary)
            .onChange(of: addOptions.monitor, initial: true) {
                movie.addOptions?.monitor = addOptions.monitor
                movie.monitored = addOptions.monitor != .none
            }
        }
    }

    var minimumAvailabilityField: some View {
        Picker(selection: $movie.minimumAvailability) {
            ForEach(availabilities, id: \.self) { availability in
                Text(availability.label).tag(availability)
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                Text("Minimum Availability")
                Text("Min. Availability", comment: "Shorter version of Minimum Availability")
                Text("Availability", comment: "Very short version of Minimum Availability")
            }
        }
        .tint(.secondary)
    }

    @ViewBuilder
    var qualityProfileField: some View {
        if instance.qualityProfiles.isEmpty {
            LabeledContent("Quality Profile") {
                Text("Error")
            }
        } else {
            Picker(selection: $movie.qualityProfileId) {
                ForEach(instance.qualityProfiles) { profile in
                    Text(profile.name)
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    Text("Quality Profile")
                    Text("Quality")
                }
            }
            .tint(.secondary)
        }
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
                Text(movie.tags.isEmpty ? "None" : "\(movie.tags.count) Tag")
            }
        }
    }
#endif

    var rootFolderField: some View {
        Picker("Root Folder", selection: $movie.rootFolderPath) {
            ForEach(instance.rootFolders) { folder in
                folder.labelWithSpace
                    .tag(folder.path)
            }
        }
        .pickerStyle(.inline)
        .tint(settings.theme.tint)
        .accentColor(settings.theme.tint) // `.tint()` is broken on inline pickers
    }

    func selectDefaultValues() {
        guard !defaultsSet else { return }
        defaultsSet = true

        if !movie.exists {
            addOptions.monitor = movieDefaults.monitor

            movie.addOptions = addOptions
            movie.monitored = movieDefaults.monitor != .none
            movie.rootFolderPath = movieDefaults.rootFolder
            movie.qualityProfileId = movieDefaults.qualityProfile
            movie.minimumAvailability = movieDefaults.minimumAvailability
        }

        if !availabilities.contains(movie.minimumAvailability) {
            movie.minimumAvailability = .announced
        }

        if !instance.qualityProfiles.contains(where: {
            $0.id == movie.qualityProfileId
        }) {
            movie.qualityProfileId = instance.qualityProfiles.first?.id ?? 0
        }

        movie.rootFolderPath = movie.rootFolderPath?.untrailingSlashIt

        if let fallback = instance.rootFolders.first?.path,
           !instance.rootFolders.contains(where: {
               $0.path?.untrailingSlashIt == movie.rootFolderPath
           }) {
            movie.rootFolderPath = fallback
        }
    }

    func tags() -> Binding<Set<Tag.ID>> {
        Binding(
            get: { Set(movie.tags) },
            set: { movie.tags = Array($0) }
        )
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    NavigationStack {
        MovieForm(movie: Binding(get: { movie }, set: { _ in }))
    }
    .withRadarrInstance(movies: movies)
    .withAppState()
}

#Preview("Existing") {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    NavigationStack {
        MovieForm(movie: Binding(get: { movie }, set: { _ in }))
    }
    .withRadarrInstance(movies: movies)
    .withAppState()
}
