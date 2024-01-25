import SwiftUI

struct MovieForm: View {
    var instance: Instance
    @State var movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(movie.title)
                .font(.largeTitle)
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

                Section("Root Folder") {
                    Picker("", selection: $movie.rootFolderPath) {
                        ForEach(instance.rootFolders) { folder in
                            HStack {
                                Text(folder.humanLabel)
                                Spacer()
                            }.tag(folder.path)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.navigationLink)
                }.onAppear {
                    print($movie.rootFolderPath)
                    print(instance.rootFolders)
                }

                if movie.exists {
                    Section {
                        Button("Delete Movie", role: .destructive) {
                            // showingConfirmation = true
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .scrollDisabled(true)
        }
    }
}
