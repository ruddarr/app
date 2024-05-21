import SwiftUI

struct MovieForm: View {
    @Binding var movie: Movie

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @Environment(\.deviceType) private var deviceType

    @State private var showingConfirmation = false

    var availabilities: [MovieStatus] = [
        .announced,
        .inCinemas,
        .released,
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Monitored", isOn: $movie.monitored)
                    .tint(settings.theme.safeTint)

                minimumAvailabilityField
                qualityProfileField
            }

            if instance.rootFolders.count > 1 {
                rootFolderField.tint(.secondary)
            }
        }
        .onAppear {
            selectDefaultValues()
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
                Text("Min. Availability")
                Text("Availability")
            }
        }
        .tint(.secondary)
    }

    var qualityProfileField: some View {
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

    var rootFolderField: some View {
        Picker("Root Folder", selection: $movie.rootFolderPath) {
            ForEach(instance.rootFolders) { folder in
                Text(folder.label).tag(folder.path)
            }
        }
        .pickerStyle(.inline)
    }

    func selectDefaultValues() {
        if !availabilities.contains(movie.minimumAvailability) {
            movie.minimumAvailability = .announced
        }

        if !instance.qualityProfiles.contains(where: {
            $0.id == movie.qualityProfileId
        }) {
            movie.qualityProfileId = instance.qualityProfiles.first?.id ?? 0
        }

        // remove trailing slashes
        movie.rootFolderPath = movie.rootFolderPath?.untrailingSlashIt

        if !instance.rootFolders.contains(where: {
            $0.path?.untrailingSlashIt == movie.rootFolderPath
        }) {
            movie.rootFolderPath = instance.rootFolders.first?.path ?? ""
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    return MovieForm(movie: Binding(get: { movie }, set: { _ in }))
        .withRadarrInstance(movies: movies)
        .withAppState()
}

#Preview("Existing") {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    return MovieForm(movie: Binding(get: { movie }, set: { _ in }))
        .withRadarrInstance(movies: movies)
        .withAppState()
}
