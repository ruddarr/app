import SwiftUI

struct MovieReleasesView: View {
    @Binding var movie: Movie

    @State private var sort: MovieReleaseSort = .init()
    @State private var indexer: String = ""
    @State private var quality: String = ""
    @State private var fetched = false

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
                        Text("This may take a moment.").font(.footnote)
                    }
                }.tint(.secondary)
            } else if instance.releases.items.count == 0 {
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
                Menu("Indexers") {
                    Picker("Indexers", selection: $indexer) {
                        ForEach(indexers, id: \.self) { indexer in
                            Text(indexer).tag(Optional.some(indexer))
                        }

                        Text("All Indexers").tag("")
                    }
                }

                Menu("Quality Profiles") {
                    Picker("Quality Profiles", selection: $quality) {
                        ForEach(qualities, id: \.self) { quality in
                            Text(quality).tag(Optional.some(quality))
                        }

                        Text("All Quality Profiles").tag("")
                    }
                }

                Picker("Sorting options", selection: $sort.option) {
                    ForEach(MovieReleaseSort.Option.allCases) { option in
                        Text(option.title).tag(option)
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
}

struct MovieReleaseRow: View {
    var release: MovieRelease

    @State private var isShowingPopover = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    if !release.indexerFlags.isEmpty {
                        // TODO: better flag!
                        Image(systemName: "flag")
                            .symbolVariant(.fill)
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                    }

                    Text(release.title)
                        .font(.callout)
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
                        Text("•")
                        Text(release.indexerLabel)
                    }
                    .lineLimit(1)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.trailing, 10)

            Spacer()

            Group {
                if release.rejected {
                    Image(systemName: "exclamationmark")
                        .symbolVariant(.circle.fill)
                        .imageScale(.large)
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "arrow.down")
                        .symbolVariant(.circle)
                        .imageScale(.large)
                }
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

    var peerColor: any ShapeStyle {
        return switch release.seeders ?? 0 {
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
