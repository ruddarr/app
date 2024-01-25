import SwiftUI

struct MovieEditView: View {
    var instance: Instance
    @State var movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(movie.title)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)

            Form {

                Section {
                    Toggle("Monitored", isOn: $movie.monitored)

                    Picker(selection: $movie.minimumAvailability) {
                        Text(MovieStatus.announced.label).tag(MovieStatus.announced)
                        Text(MovieStatus.inCinemas.label).tag(MovieStatus.inCinemas)
                        Text(MovieStatus.released.label).tag(MovieStatus.released)
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

                Section("Root") {
                    Picker("", selection: $movie.rootFolderPath) {
                        ForEach(instance.rootFolders) { folder in
                            Text(
                                "\(folder.path!)"
                            )
//                            let freeSpace: Int?
                        }
                    }
                }

                Section {
                    Button("Delete Movie", role: .destructive) {
                        // showingConfirmation = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .scrollDisabled(true)
        }
        .navigationBarTitleDisplayMode(.inline)
        .padding(.top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { }
            }
        }

    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies[232]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(MoviesView.Path.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesView.Path.edit(movie.id))

    return ContentView()
        .withSettings()
}
