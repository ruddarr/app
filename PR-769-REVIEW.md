# Code Review — PR #769 "Fix onBecomeActive firing on every view appearance"

- **Branch:** `claude/on-become-active-fix` (head `c5adc9bd`), base `develop`
- **Reviewed:** 2026-08-05, maximum-recall pass (10 finder angles, one verifier per candidate, gap sweep)
- **Files in scope:** `Ruddarr/Utilities/View.swift`, `Ruddarr/Models/Movies/Movies.swift`, `Ruddarr/Models/Series/SeriesModel.swift`, `Ruddarr/Views/MoviesView.swift`, `Ruddarr/Views/SeriesView.swift`, `Ruddarr/Views/ContentView.swift`, `Ruddarr/Views/ContentViewMac.swift`, `Ruddarr/Dependencies/API/API+Mock.swift`, `CHANGELOG.md`, `TestFlight/WhatToTest.en-US.txt`

Line numbers below refer to the PR head revision.

## Summary

The PR does what it says for the library views: the `initial: false` default stops the per-appearance
refetch storm, and the `fetchTask` dedupe correctly coalesces the overlapping launch fetches
(verified: `@MainActor` isolation leaves no check/set gap, no cross-instance join after `switchTo`,
no leak, `defer` always clears).

Two problem clusters remain:

1. **The default flip silently changed 10 call sites, and three flows depended on the removed
   initial fire.** The calendar detail sheets were designed around partial seeded payloads being
   backfilled by the on-appearance `reload()`; that backfill is gone. DiagnosticsView loses its
   only `appDiagnostics` load.
2. **The launch path still double-fires.** `initial: false` does not suppress the
   `.inactive -> .active` transition at cold launch (empirically verified: the transition lands
   ~120ms after first render and fires `onChange`), so `.task` and `becameActive` both run. The
   movies fetch dedupes; the metadata fetch does not.

## Findings (ranked most severe first)

### 1. Calendar sheet: SeasonView shows only the single seeded episode — CONFIRMED

`Ruddarr/Views/Series/SeasonView.swift:50`

Calendar tab -> tap a grouped episode entry: `CalendarEpisodeSheet` seeds
`instance.episodes.items = [episode]` (`CalendarDetailSheet.swift:120`) and pushes
`SeriesPath.season`. `SeriesEpisodes.fetched(series)` is `items.contains { $0.seriesId == series.id }`
(`SeriesEpisodes.swift:39-41`), which the one seeded episode satisfies, so the `.task`'s
`maybeFetch` no-ops and `hasFetched` flips true with no spinner. The scene is already active, so
`onBecomeActive { await reload() }` (previously fired on appearance via the hardcoded
`initial: true`) never runs. Result: the season lists exactly one episode, with no automatic
recovery — only pull-to-refresh, the Refresh command, or backgrounding the app heals it.

### 2. Calendar sheet: EpisodeView never loads the file section — CONFIRMED

`Ruddarr/Views/Series/EpisodeView.swift:72`

Sonarr's `/api/v3/calendar` request omits `includeEpisodeFile` (`API+Live.swift`, `episodeCalendar`
vs `fetchEpisodes`), so the seeded episode has `episodeFile == nil` while `hasFile == true`.
`.task(id: episodeId)` only runs `setEpisodeState()` (copies the nil) and `fetchHistory`. The file
section (`EpisodeView.swift:42`, `if episodeFile != nil`) and the toolbar Delete File section never
render for a downloaded episode, and Video/Audio details fall back to "Unknown".

### 3. Pull-to-refresh joins a pre-gesture fetch; can resurrect a deleted item — CONFIRMED

`Ruddarr/Models/Movies/Movies.swift:85` (same: `Ruddarr/Models/Series/SeriesModel.swift:86`)

`fetch()` joins any in-flight `fetchTask`, including for user-initiated refreshes. On a slow
instance: fetch F1 in flight -> user deletes a movie (`.delete` removes it locally, no refetch) ->
pops back and pulls to refresh -> `fetchMoviesWithAlert` joins F1 -> F1's pre-delete response
wholesale-overwrites `items` (`Movies.swift:143-145`) -> the deleted movie reappears as the result
of the user's refresh, with no correcting request (a just-added item symmetrically vanishes).
Pre-PR, the refresh always issued a post-mutation request that corrected the transient state.

*Suggested fix:* give the `.refreshable` path force semantics (await any in-flight task, then issue
a fresh request), or clear `fetchTask` on mutating operations.

### 4. Calendar sheet: SeriesDetailView missing statistics, no self-heal — CONFIRMED

`Ruddarr/Views/Series/SeriesItemView.swift:43`

The sheet seeds `instance.series.items` with the calendar-embedded series, which never carries
`statistics` (cross-checked against Sonarr's `SeriesResource.ToResource`, which does not populate
it for embeds; the `calendar-episodes.json` fixture matches). Size-on-disk and per-season progress
stay hidden, `maybeFetch` no-ops (finding 1's mechanism), and the on-appearance `reload()` that
used to backfill the full record is gone.

### 5. Cold launch double metadata fetch — CONFIRMED (empirically)

`Ruddarr/Views/MoviesView.swift:224` (same: `Ruddarr/Views/SeriesView.swift:235`)

At every iOS cold launch both `.task` and the `.inactive -> .active` transition's `becameActive`
run (verified with a minimal simulator app: transition fires `onChange(initial: false)` ~120ms
after first render). Both join the same movies `fetchTask`, resume together, and both pass
`Occurrence.since(...) > cacheInSeconds` because `Occurrence.occurred` is stamped only after
`fetchMetadata()`'s network round-trip completes. Result whenever the stamp is stale: 6 metadata
requests instead of 3 (rootFolders, qualityProfiles, tags twice), `InstanceStats.make` over the
whole library twice, `saveInstanceMetadata` twice — the "redundant network requests at launch"
class the changelog claims fixed.

*Suggested fix:* stamp (or set an in-flight marker) before awaiting, or dedupe `fetchMetadata`
with a task handle mirroring `fetchTask`.

### 6. DiagnosticsView export missing App/Notifications sections — CONFIRMED

`Ruddarr/Views/Settings/DiagnosticsView.swift:25`

`appDiagnostics` is assigned only inside `onBecomeActive`; the `.task` `refresh()` loop sets only
`report`/`failedRequests`. On first open in an active scene it stays nil, so
`DiagnosticsReport(app: nil)` omits the App and Notifications sections. Scope refinement from
verification: those rows are all `.exportOnly`, so the on-screen list is visually unchanged — the
loss is in the share/export output (Locale, Region, Subscription, Entitled, Push Authorization,
iCloud Account), exported incomplete with no indication. The view was not migrated to
`initial: true` the way ContentView was.

### 7. Mock `getSeries` force-unwrap crash (dev tooling only) — CONFIRMED

`Ruddarr/Dependencies/API/API+Mock.swift:77`

14 of 20 series ids embedded in `calendar-episodes.json` (404–525) do not exist in `series.json`
(ids top out ~383). With the opt-in whole-app mock enabled (uncommenting `dependencies.api = .mock`,
`Ruddarr.swift:19` — not reachable from `#Preview` or default DEBUG runs), Calendar -> tap such an
episode -> any `series.get` trigger -> `series.first(where: { $0.id == seriesId })!` traps. The old
code returned `series[0]` and never crashed. Note: the `getMovie` mock (line 24) has the identical
latent pattern and all 11 `calendar-movies.json` ids are likewise missing — aligning the fixtures
or using `?? series[0]` fixes both.

### 8. macOS: metadata fetch can be silently skipped at launch — PLAUSIBLE

`Ruddarr/Views/MoviesView.swift:57`

On macOS the metadata fetch now lives only in the cancellable `.task` (if `appearsActive` is
already true at first evaluation, `onChange(initial: false)` never fires at launch, so there is no
`becameActive` fallback — this premise is undocumented and unverified). Fresh install/relaunch with
empty persisted metadata: user clicks into a movie while the un-cancellable library fetch is in
flight -> `.task` cancelled -> `fetchInstanceMetadata()`'s requests throw `CancellationError`
immediately, nothing stamped -> `MovieForm` shows "Error" for Quality Profile
(`MovieForm.swift:88-91`) while the user stays in the pushed subtree. Self-heals on pop-back or
tab switch. Pre-PR the metadata fetch ran in an uncancellable unstructured Task fired on appearance.

### 9. Non-overlap launch ordering: second full library fetch — PLAUSIBLE

`Ruddarr/Views/MoviesView.swift:214`

The dedupe only coalesces overlapping calls. If the `.task` fetch completes before scene activation
(localhost/simulator ~10-30ms fetches; or activation delayed seconds by a launch-time system alert
such as the local-network permission prompt), `becameActive -> fetchMoviesWithMetadata -> fetch()`
finds `fetchTask == nil` and downloads/decodes the full library a second time, unthrottled. In the
common ordering (network slower than ~120ms activation) the dedupe works as intended.

### 10. Foreground fetch never stamps `lastFetch` — CONFIRMED, pre-existing gap preserved

`Ruddarr/Views/MoviesView.swift:212` (same: `Ruddarr/Views/SeriesView.swift:223`)

`fetchMoviesWithMetadata()` fetches the full library but never sets `lastFetch` (only
`fetchMoviesThrottled` does, line 236). Foreground on the Movies tab at t=0, tab away and back at
t=5-10s: the `.task` throttle sees a stale `lastFetch` and refetches the whole library seconds
after the foreground fetch. Verified byte-identical on `develop` — an incomplete fix within the
PR's stated goal, not a regression. One-line follow-up: stamp `lastFetch` there (both views); this
also closes finding 9.

### 11. Unstructured fetch task severs structured cancellation — PLAUSIBLE (low, largely by design)

`Ruddarr/Models/Movies/Movies.swift:89` (same: `SeriesModel.swift:90`)

A `.task`-initiated fetch now always runs the full download/decode to completion after the view
disappears (pre-PR, URLSession aborted promptly via `CancellationError`), and the cancelled caller
stays suspended on the non-cancellable `Task.value` before running its continuation in a cancelled
context. Verification narrowed this considerably: 3 of 4 fetch triggers were already
non-cancellable pre-PR (`.refreshable` deliberately so), the surviving result lands as useful
prefetch in the long-lived shared model, and the instance-switch orphan work is unchanged from
`develop`. Worth a design comment or a `cancelFetch()` hook, not a rework.

### 12. Mock change is outside the PR's task (CLAUDE.md ground rule 3) — PLAUSIBLE (conventions, low)

`Ruddarr/Dependencies/API/API+Mock.swift:73`

CLAUDE.md: "Don't touch unrelated code. If a file or function is not directly part of the current
task, do not modify it." `getSeries` backs only `SeriesModel.get(_:)`, which the PR does not
otherwise touch. Defensible — the initial flip changes when previews exercise `get()`, and the old
wrong-series mock would mask the behavior under test; it also converges with the `getMovie`
pattern — but it rides along uncommented. Worth a sentence in the PR description.

### 13. Redundant `Task { @MainActor }` double-wrap — optional nit (wrapper predates the PR)

`Ruddarr/Views/MoviesView.swift:213` (same: `SeriesView.swift:224`)

`fetchMoviesWithMetadata`'s only caller is `becameActive` via `onBecomeActive`, whose modifier
already wraps the action in `Task { await action() }`. Since the PR edited this function's body
anyway, making it async and passing it directly (the pattern all 8 other call sites use) was free.
Cleanup-if-touching, not a defect.

## Checked and cleared (refuted candidates)

- **MovieView "data hole" on open** — refuted. Radarr's `/api/v3/calendar` returns full
  `MovieResource` objects including `movieFile` (the calendar grid's downloaded checkmarks depend
  on this in-repo), and `fetchMovies` passes no special query items. What remains is the intended
  staleness tradeoff the changelog describes. (Contrast finding 2: Sonarr gates file data behind an
  include flag, Radarr does not.)
- **`changeInstance()` metadata fetch bypassing the Occurrence stamp** — refuted as a PR defect:
  byte-identical on `develop`, and the PR strictly reduces triggers on that path. Valid tiny
  follow-up outside this PR.
- **`fetchInstanceMetadata` duplication across MoviesView/SeriesView** — refuted: the throttle
  block existed inline in both files pre-PR (zero net new copies), the mirrored-twin structure is
  the codebase norm, and consolidation would need a cross-cutting refactor (no shared instance
  protocol; `AppSettings` unreachable from the model layer).
- **Serialized `await fetchMoviesThrottled(); await fetchInstanceMetadata()`** — refuted: the
  ordering is load-bearing (`InstanceStats.make` needs fetched items; `async let` would lock in
  stats-less metadata for a full throttle window), and the PR strictly improves metadata latency
  vs `develop`, which fetched no metadata at launch at all.
- **Dedupe mechanics** — verified sound: `@MainActor` leaves no check/set gap; non-throwing
  `Task.value` guarantees the `defer` clears `fetchTask`; `switchTo` replaces the model objects so
  no cross-instance join; all `fetch()` callers discard the Bool, so the shared-result contract has
  no consumer to break; ContentView/ContentViewMac `initial: true` reproduces pre-PR launch
  behavior exactly once.

## Suggested fix priorities

1. Restore backfill for the calendar sheets (findings 1, 2, 4): either pass a way to force the
   initial fire for sheet-hosted views, or have `CalendarEpisodeSheet` trigger an explicit
   `series.get` + `episodes.fetch` instead of relying on seeded items (also stops seeded items from
   satisfying `fetched()`).
2. Give `.refreshable` force semantics past the dedupe (finding 3).
3. Single-flight or pre-stamp the metadata fetch (finding 5); stamp `lastFetch` in the
   `WithMetadata` paths (findings 9, 10).
4. Migrate DiagnosticsView (finding 6): load `appDiagnostics` from its `.task` (or pass
   `initial: true`).
5. Fixture alignment or non-trapping fallback in the mocks (finding 7).
