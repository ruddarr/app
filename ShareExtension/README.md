# Share Extension

Self-contained share extension that searches for media on Radarr/Sonarr
instances and adds them directly via API without requiring the main app.

## Flow

1. User shares a URL from a supported site
2. Extension parses the URL to extract a search query
3. If multiple instances exist, user picks one
4. Extension searches the Radarr/Sonarr API and displays results in a poster grid
5. User taps a result to see a preview (poster, details, ratings, overview)
6. User taps "Add" to configure quality profile, root folder, and monitoring
7. Extension POSTs directly to the Radarr/Sonarr API to add the media

## Duplicated Views

Views duplicated in the share extension due to deep dependency chains
in the main app (`RadarrInstance`/`SonarrInstance`, `AppSettings`,
`dependencies.router`, `Telemetry`, `Sentry`, `Nuke`, etc.):

| Extension View | Main App Equivalent | Notes |
|---|---|---|
| `ShareGridPoster` | `MovieGridPoster` / `SeriesGridPoster` | Poster with gradient overlay, status icons, bookmark |
| `ShareMoviePreviewView` | `MoviePreviewView` + `MovieDetails` header | Poster+title header, detail rows, description, ratings |
| `ShareSeriesPreviewView` | `SeriesPreviewView` + `SeriesDetails` header | Same layout adapted for series |
| `ShareMovieSearchView` / `ShareSeriesSearchView` | `MovieSearchView` / `SeriesSearchView` | Search results grid |
| `ShareMovieResult` / `ShareSeriesResult` | `Movie` / `Series` | Lightweight models + raw JSON for POST |
| `ShareAPIClient` | `API` + `API+Live` | Standalone URLSession client |
| `ShareSearchCoordinator` | `MovieLookup` / `SeriesLookup` | ObservableObject search state |
| `ShareInstanceConfig` | `RadarrInstance` / `SonarrInstance` | Fetches quality profiles + root folders |
| Add form in preview views | `MovieForm` / `SeriesForm` | Quality profile, root folder, monitoring pickers |
| Detail rows in previews | `MediaDetailsRow` | Status/genre/studio grid rows |

## TODOs

- [ ] Migrate instance data to App Groups shared container
- [ ] Sync instances to App Groups shared container
- [x] Replace `AsyncImage` with NukeUI `LazyImage` (add Nuke dependency to extension target)
- [ ] Deduplicate models/views by extracting shared code into a framework or Swift package
- [x] Handle case when no instances are configured (show setup instructions)
- [x] Support monitoring type picker in add form (movieOnly, collection, etc.)
- [ ] Remember last-used add defaults per instance
