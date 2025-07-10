import SwiftUI

struct MovieForm: View {
    @Binding var movie: Movie
    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance
    @Environment(\.deviceType) private var deviceType
    @State private var showingConfirmation = false

    @AppStorage("movieDefaults", store: dependencies.store) var movieDefaults: MovieDefaults = .init()

    var body: some View {
        Form {
            Section {
                Toggle("Monitored", isOn: $movie.monitored)
                    .tint(settings.theme.safeTint)
                minimumAvailabilityField
                qualityProfileField
            }

            tagsField

            if instance.rootFolders.count > 1 {
                rootFolderField
            }
        }
        .onAppear {
            selectDefaultValues()
        }
    }
    
    var availabilities: [MovieStatus] = [.announced, .inCinemas, .released]

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

    var tagsField: some View {
        Menu {
            ForEach(instance.tags) { tag in
                Button {
                    if movie.tags.contains(tag.id) {
                        movie.tags.removeAll { $0 == tag.id }
                    } else {
                        movie.tags.append(tag.id)
                    }
                } label: {
                    HStack {
                        Text(tag.label)
                        if movie.tags.contains(tag.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(movie.tags.isEmpty ? "Optional Tags".localizedCapitalized : instance.tags.filter { movie.tags.contains($0.id) }.map { $0.label }.joined(separator: ", "))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .tint(.secondary)
    }

    var rootFolderField: some View {
        Picker("Root Folder", selection: $movie.rootFolderPath) {
            ForEach(instance.rootFolders) { folder in
                Text(folder.label).tag(folder.path)
            }
        }
        .pickerStyle(InlinePickerStyle())
        .tint(settings.theme.tint)
        .accentColor(settings.theme.tint)
    }

    func selectDefaultValues() {
        if !movie.exists {
            movie.monitored = movieDefaults.monitored
            movie.rootFolderPath = movieDefaults.rootFolder
            movie.qualityProfileId = movieDefaults.qualityProfile
            movie.minimumAvailability = movieDefaults.minimumAvailability
            movie.tags = movieDefaults.tags
        }

        if !availabilities.contains(movie.minimumAvailability) {
            movie.minimumAvailability = .announced
        }

        if !instance.qualityProfiles.contains(where: { $0.id == movie.qualityProfileId }) {
            movie.qualityProfileId = instance.qualityProfiles.first?.id ?? 0
        }

        movie.rootFolderPath = movie.rootFolderPath?.untrailingSlashIt

        if !instance.rootFolders.contains(where: { $0.path?.untrailingSlashIt == movie.rootFolderPath }) {
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
