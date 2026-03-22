import SwiftUI

extension Image.Scale {
    static var gridItem: Image.Scale {
        switch Platform.deviceType {
        case .phone: .small
        case .mac: .large
        default: .medium
        }
    }
}

struct MediaGridPosterOverlay<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            content
        }
        .font(.body)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct DiscoveryGridPoster: View {
    var item: DiscoveryItem

    @State private var isLoading = false

    @State private var error: API.Error?

    @Environment(RadarrInstance.self) private var radarrInstance
    @Environment(SonarrInstance.self) private var sonarrInstance

    var body: some View {
        Button {
            Task {
                await navigate()
            }
        } label: {
            CachedAsyncImage(.poster, item.poster_path, placeholder: item.title)
                .aspectRatio(
                    CGSize(width: 150, height: 225),
                    contentMode: .fill
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.card)
                .overlay(alignment: .bottom) {
                    if let movie {
                        MoviePosterOverlay(movie: movie)
                    } else if let series {
                        SeriesPosterOverlay(series: series)
                    }
                }
                .opacity(inLibrary ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLoading)
        .animation(.spring(duration: 0.2), value: isLoading)
        .overlay {
            if isLoading {
                Color.black.opacity(0.7)
                ProgressView().tint(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .alert(
            isPresented: Binding(
                get: { self.error != nil },
                set: { _ in }
            ),
            error: error
        ) { _ in
            Button("OK") { error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
    }

    var inLibrary: Bool {
        movie != nil || series != nil
    }

    var movie: Movie? {
        guard item.type == .movie else { return nil }
        return radarrInstance.movies.cachedItems.first { $0.tmdbId == item.id }
    }

    var series: Series? {
        guard item.type == .series else { return nil }
        return sonarrInstance.series.cachedItems.first { $0.tmdbId == item.id }
    }

    func navigate() async {
        if item.type == .movie {
            await navigateTo(movie: movie)
        } else if item.type == .series {
            await navigateTo(series: series)
        }
    }

    func navigateTo(movie: Movie?) async {
        if let movie {
            dependencies.router.moviesPath.append(MoviesPath.movie(movie.id))
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let result = try await radarrInstance.lookup.fetch(tmdb: item.id) else {
                let message = String(format: String(localized: "No Results for \"%@\""), item.title)
                self.error = API.Error(from: AppError(message))
                return
            }

            let data = try JSONEncoder().encode(result)
            dependencies.router.moviesPath.append(MoviesPath.preview(data))
        } catch {
            self.error = API.Error(from: error)
        }
    }

    func navigateTo(series: Series?) async {
        if let series {
            dependencies.router.seriesPath.append(SeriesPath.series(series.id))
            return
        }

        if sonarrInstance.series.cachedItems.first(where: { $0.tmdbId != nil }) == nil {
            self.error = API.Error(from: AppError(
                String(localized: "Upgrade to Sonarr v4.0.5 or newer.")
            ))

            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let result = try await sonarrInstance.lookup.fetch(tmdb: item.id) else {
                let message = String(format: String(localized: "No Results for \"%@\""), item.title)
                self.error = API.Error(from: AppError(message))
                return
            }

            let data = try JSONEncoder().encode(result)
            dependencies.router.seriesPath.append(SeriesPath.preview(data))
        } catch {
            self.error = API.Error(from: error)
        }
    }
}

struct DiscoveryRail<Path: Hashable>: View {
    var title: LocalizedStringKey
    var items: [DiscoveryItem]
    var seeAllLabel: LocalizedStringKey
    var destination: Path?

    private let posterWidth: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        DiscoveryGridPoster(item: item)
                            .frame(width: posterWidth)
                    }

                    if let destination {
                        NavigationLink(value: destination) {
                            DiscoverySeeAllPoster(label: seeAllLabel)
                                .frame(width: posterWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

struct DiscoverySeeAllPoster: View {
    var label: LocalizedStringKey

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.card)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .imageScale(.large)

                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding(12)
            }
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fit
            )
            .accessibilityLabel(Text(label))
    }
}

#Preview {
    let items: DiscoveryItems = PreviewData.loadObject(name: "popular-movies")

    VStack {
        DiscoveryGridPoster(item: items.popular[3])
        DiscoveryGridPoster(item: items.popular[12])
        DiscoveryGridPoster(item: items.popular[13])
    }
    .environment(RadarrInstance())
    .environment(SonarrInstance())
    .frame(width: 150, height: 225)
}
