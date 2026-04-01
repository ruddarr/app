# Share Extension

## Duplicated Views

Views duplicated in the share extension due to deep dependency chains
in the main app (`RadarrInstance`/`SonarrInstance`, `AppSettings`,
`dependencies.router`, `Telemetry`, `Sentry`, `Nuke`, etc.):

| Extension View | Main App Equivalent | Notes |
|---|---|---|
| `ShareGridPoster` | `MovieGridPoster` / `SeriesGridPoster` | Poster with gradient overlay, status icons, bookmark |
| `ShareMoviePreviewView` | `MoviePreviewView` + `MovieDetails` header | Poster+title header, detail rows, description, ratings |
| `ShareSeriesPreviewView` | `SeriesPreviewView` + `SeriesDetails` header | Same layout adapted for series |
| `ShareSearchView` (grid layout) | `MediaGrid` | Adaptive poster grid columns |
| `ShareMovieResult` / `ShareSeriesResult` | `Movie` / `Series` | Lightweight Codable subsets |
| `ShareAPIClient` | `API` + `API+Live` | Standalone URLSession lookup |
| `ShareSearchCoordinator` | `MovieLookup` / `SeriesLookup` | ObservableObject search state |
| Detail rows in previews | `MediaDetailsRow` | Status/genre/studio grid rows |

## TODOs

- [ ] Migrate instance data to App Groups shared container
- [ ] Sync `url`, `apiKey`, and `headers` to `ShareInstance` via App Groups
- [ ] Replace `AsyncImage` with `CachedAsyncImage` (add Nuke dependency to extension target)
- [ ] Deduplicate models/views by extracting shared code into a framework or Swift package
- [ ] Add "Add to Library" directly from extension (requires quality profiles, root folders API)
- [ ] Handle case when no instances are configured (show setup instructions)
