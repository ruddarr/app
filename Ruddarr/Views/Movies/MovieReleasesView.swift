import SwiftUI

struct MovieReleasesView: View {
    @Binding var movie: Movie

    @State private var sort: MovieReleaseSort = .init()
    @State private var indexer: String = ""
    @State private var quality: String = ""
    @State private var fetched: Bool = false
    @State private var waitingTextOpacity: Double = 0

    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        Group {
            List {
                ForEach(displayedReleases) { release in
                    MovieReleaseRow(release: release)
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("Releases")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarSortingButton
        }
        .task {
            guard !fetched else { return }

            await instance.releases.search(movie)

            fetched = true
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { instance.releases.error != nil }, set: { _ in }),
            presenting: instance.releases.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            if instance.releases.isSearching {
                ProgressView {
                    VStack {
                        Text("Searching...")
                        Text("Hold on, this may take a moment.")
                            .font(.footnote)
                            .opacity(waitingTextOpacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { waitingTextOpacity = 1 }
                                }
                            }
                    }
                }.tint(.secondary)
            } else if instance.releases.items.isEmpty {
                ContentUnavailableView(
                    "No Releases Found",
                    systemImage: "slash.circle",
                    description: Text("Radarr found no releases for \"\(movie.title)\".")
                )
            }
        }
    }

    var displayedReleases: [MovieRelease] {
        var sortedReleases = instance.releases.items.sorted(
            by: sort.option.isOrderedBefore
        )

        if !indexer.isEmpty {
            sortedReleases = sortedReleases.filter { $0.indexerLabel == indexer }
        }

        if !quality.isEmpty {
            sortedReleases = sortedReleases.filter { $0.quality.quality.name == quality }
        }

        return sort.isAscending ? sortedReleases : sortedReleases.reversed()
    }

    var indexers: [String] {
        var seen: Set<String> = []

        return instance.releases.items
            .map { $0.indexerLabel }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    var qualities: [String] {
        var seen: Set<String> = []

        return instance.releases.items
            .map { $0.quality.quality.name ?? "Unknown" }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    @ToolbarContentBuilder
    var toolbarSortingButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu("Sorting & Filters", systemImage: "line.3.horizontal.decrease") {
                indexersPicker

                qualityPicker

                Picker("Sorting options", selection: $sort.option) {
                    ForEach(MovieReleaseSort.Option.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }.onChange(of: sort.option) {
                    switch sort.option {
                    case .byWeight: sort.isAscending = false
                    case .byAge: sort.isAscending = true
                    case .bySize: sort.isAscending = true
                    case .bySeeders: sort.isAscending = false
                    }
                }

                Section {
                    Picker("Sorting direction", selection: $sort.isAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                }
            }
        }
    }

    var indexersPicker: some View {
        Menu("Indexer") {
            Picker("Indexer", selection: $indexer) {
                ForEach(indexers, id: \.self) { indexer in
                    Text(indexer).tag(Optional.some(indexer))
                }

                Text("All Indexers").tag("")
            }
        }
    }

    var qualityPicker: some View {
        Menu("Quality Profile") {
            Picker("Quality Profile", selection: $quality) {
                ForEach(qualities, id: \.self) { quality in
                    Text(quality).tag(Optional.some(quality))
                }

                Text("All Quality Profiles").tag("")
            }
        }
    }
}

struct MovieReleaseRow: View {
    var release: MovieRelease

    @State private var isShowingPopover = false

    var body: some View {
        HStack {
            linesStack
                .padding(.trailing, 10)

            Spacer()

            if release.rejected {
                Image(systemName: "exclamationmark.triangle")
                    .symbolVariant(.fill)
                    .imageScale(.medium)
                    .foregroundColor(.orange)
            } else if !release.indexerFlags.isEmpty {
                Image(systemName: "flag")
                    .symbolVariant(.fill)
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture {
            isShowingPopover = true
        }
        .sheet(isPresented: $isShowingPopover) {
            MovieReleaseSheet(release: release)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
    }

    var linesStack: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Text(release.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            Group {
                HStack(spacing: 6) {
                    Text(release.qualityLabel)
                    Text("•")
                    Text(release.sizeLabel)
                    Text("•")
                    Text(release.ageLabel)
                }
                .lineLimit(1)

                HStack(spacing: 6) {
                    Text(release.typeLabel)
                        .foregroundStyle(peerColor)
                        .opacity(0.75)
                    Text("•")
                    Text(release.indexerLabel)
                }
                .lineLimit(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    var peerColor: any ShapeStyle {
        switch release.seeders ?? 0 {
        case 50...: .green
        case 10..<50: .blue
        case 1..<10: .orange
        default: .red
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 66 }) ?? movies[0]

    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesView.Path.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesView.Path.releases(movie.id))

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
