import SwiftUI
import TipKit

struct MovieMetadataView: View {
    @Binding var movie: Movie

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @State private var videoExpanded: Bool = false
    @State private var audioExpanded: Bool = false

    @State private var fileSheet: MediaFile?
    @State private var eventSheet: MediaHistoryEvent?

    var body: some View {
        ScrollView {
            Group {
                files
                history
            }
            .padding(.vertical)
            .viewPadding(.horizontal)
        }
        .navigationTitle(movie.title)
        .safeNavigationBarTitleDisplayMode(.inline)
        .onAppear {
            instance.metadata.setMovie(movie)
        }
        .refreshable {
            await Task {
                await instance.metadata.refresh(for: movie)
            }.value
        }
    }

    var files: some View {
        Section {
            if instance.metadata.filesLoading {
                ProgressView().tint(.secondary)
            } else if instance.metadata.filesError {
                noContent("An error occurred.")
            } else if instance.metadata.files.isEmpty && instance.metadata.extraFiles.isEmpty {
                noContent("Movie has no files.")
            } else {
                if !instance.metadata.files.isEmpty {
                    TipView(DeleteFileTip(), arrowEdge: .bottom)
                }

                ForEach(instance.metadata.files) { file in
                    MovieFilesFile(file: file)
                        .padding(.bottom, 4)
                        .onTapGesture { fileSheet = file }
                }

                ForEach(instance.metadata.extraFiles) { file in
                    MovieFilesExtraFile(file: file)
                        .padding(.bottom, 4)
                }
            }
        } header: {
            Text("Files")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await instance.metadata.fetchFiles(for: movie)
        }
        .sheet(item: $fileSheet) { file in
            MediaFileSheet(file: file, runtime: movie.runtime)
                .presentationDetents([.fraction(0.9)])
        }
    }

    var history: some View {
        Section {
            if instance.metadata.historyLoading {
                ProgressView().tint(.secondary)
            } else if instance.metadata.historyError {
                noContent("An error occurred.")
            } else if instance.metadata.history.isEmpty {
                noContent("Movie has no history.")
            } else {
                ForEach(instance.metadata.history) { event in
                    MediaHistoryItem(event: event)
                        .padding(.bottom, 4)
                        .onTapGesture { eventSheet = event }
                }
            }
        } header: {
            Text("History")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await instance.metadata.fetchHistory(for: movie)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .presentationDetents(
                    event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
        }
    }

    func noContent(_ label: LocalizedStringKey) -> some View {
        Text(label)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom)
    }
}

struct MovieFilesFile: View {
    var file: MediaFile

    @Environment(RadarrInstance.self) private var instance

    @State private var showDeleteConfirmation = false

    var body: some View {
        GroupBox {
            HStack(spacing: 6) {
                Text(file.quality.quality.label)
                Bullet()
                Text(file.languageLabel)
                Bullet()
                Text(file.sizeLabel)
                Spacer()
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } label: {
            Text(file.filenameLabel)
        }
        .contextMenu {
            Button("Delete File", systemImage: "trash", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .alert(
            "Are you sure?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete File", role: .destructive) {
                Task { await deleteFile() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase the movie file.")
        }
    }

    @MainActor
    func deleteFile() async {
        if await instance.metadata.delete(file) {
            dependencies.toast.show(.fileDeleted)
        }
    }
}

struct MovieFilesExtraFile: View {
    var file: MovieExtraFile

    var body: some View {
        GroupBox {
            HStack(spacing: 6) {
                Text(file.type.label)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } label: {
            Text(file.relativePath ?? "--")
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 295 }) ?? movies[0]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesPath.movie(movie.id)
    )

    dependencies.router.moviesPath.append(
        MoviesPath.metadata(movie.id)
    )

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
