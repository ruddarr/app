import SwiftUI

struct MovieForm: View {
    var instance: Instance

    @Binding var movie: Movie

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
        .onAppear {
            selectDefaultValues()
        }
    }

    func selectDefaultValues() {
        if !instance.qualityProfiles.contains(
            where: { $0.id == movie.qualityProfileId }
        ) {
            movie.qualityProfileId = instance.qualityProfiles.first?.id ?? 0
        }

        if !instance.rootFolders.contains(
            where: { $0.path == movie.rootFolderPath }
        ) {
            movie.rootFolderPath = instance.rootFolders.first?.path ?? ""
        }
    }
}
