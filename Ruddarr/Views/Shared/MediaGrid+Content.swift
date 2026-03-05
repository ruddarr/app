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
            let result = try await radarrInstance.lookup.fetch(tmdb: item.id)

            dependencies.router.moviesPath.append(
                MoviesPath.preview(try? JSONEncoder().encode(result))
            )
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
            let result = try await sonarrInstance.lookup.fetch(tmdb: item.id)

            dependencies.router.seriesPath.append(
                SeriesPath.preview(try? JSONEncoder().encode(result))
            )
        } catch {
            self.error = API.Error(from: error)
        }
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
