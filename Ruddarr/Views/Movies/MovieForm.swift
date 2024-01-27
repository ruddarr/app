import SwiftUI

struct MovieForm: View {
    @Binding var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @State private var showingConfirmation = false

    var availabilities: [MovieStatus] = [
        .announced,
        .inCinemas,
        .released,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(movie.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .kerning(-0.5)
                .lineLimit(2)
                .padding(.horizontal)

            Form {
                Section {
                    Toggle("Monitored", isOn: $movie.monitored)

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
                }

                Section("Root Folder") {
                    Picker("", selection: $movie.rootFolderPath) {
                        ForEach(instance.rootFolders) { folder in
                            HStack {
                                Text(folder.label)
                                Spacer()
                            }.tag(folder.path)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.navigationLink)
                }

                if movie.exists {
                    deleteMovieButton
                }
            }
            .scrollDisabled(true)
        }
        .padding(.top, 4)
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear {
            selectDefaultValues()
        }
    }

    var deleteMovieButton: some View {
        Button("Delete Movie", role: .destructive) {
            showingConfirmation = true
        }
        .confirmationDialog(
            "Are you sure you want to delete the movie and permanently erase the movie folder and its contents?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Movie", role: .destructive) {
                Task {
                    await deleteMovie(movie)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can’t undo this action.")
        }
        .frame(maxWidth: .infinity, alignment: .center)
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

    func deleteMovie(_ movie: Movie) async {
        guard await instance.movies.delete(movie) else {
            return
        }

        dependencies.router.moviesPath = .init()
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies[232]

    return MovieForm(movie: Binding(get: { movie }, set: { _ in }))
        .withSettings()
        .withRadarrInstance(movies: movies)
}
