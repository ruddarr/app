# App lifecycle refresh

How `.onBecomeActive()` works and why it is built this way.

## The problem

`OnBecomeActiveModifier` used to observe the scene phase itself, once per call site,
with `onChange(of: scenePhase, initial: true)`.

`initial: true` fires when the **view** is installed, not when the **app** becomes
active. So the modifier answered "is the app active right now?" rather than "did the
app just come back?" — and every newly installed view got a `true` and ran its refresh:

- Pushing a detail view ran both its `.task` (initial load) and its `onBecomeActive`
  action (refresh), so it fetched the same data twice.
- At cold launch every view on screen did the same.
- Each call site kept its own copy of the state, so sibling views could disagree about
  whether a resume had happened.

The root cause was treating "the app is active" as **state** that each new view re-reads,
instead of an **event** that happens at a point in time.

## What we want

1. On-screen data refreshes when the app returns to the foreground.
2. Nothing fires just because a view appeared — that is what `.task` is for.
3. One definition of "became active" for the whole app, not one per call site.

## How it works

`Lifecycle.shared` (`Ruddarr/Services/Lifecycle.swift`) publishes `resumeCount`,
incremented once per return to the foreground.

Exactly one observer per platform drives it, because the two platforms watch different
signals:

| Platform | Observer         | Signal          |
| -------- | ---------------- | --------------- |
| iOS      | `ContentView`    | `scenePhase`    |
| macOS    | `ContentViewMac` | `appearsActive` |

The observer calls `resignedActive()` when the app leaves the foreground and
`becameActive()` when it returns. `becameActive()` only fires if it was armed first, so
a cold launch — which never left the foreground — stays silent.

`.onBecomeActive()` is then just `onChange(of: Lifecycle.shared.resumeCount)`. Views
installed after the event fired never see it, which is what prevents the install-time
duplicate. The action runs on every *installed* instance, not just visible ones —
invisible tabs and views covered by a pushed destination fire too; guard inside the
action when only the visible screen should react (see `MoviesView.becameActive`).

## Rules for call sites

- Initial load goes in `.task`.
- Refresh-on-resume goes in `.onBecomeActive()`.
- A view that needs both uses both. They almost never overlap: `.task` runs on
  installation, `onBecomeActive` only on a resume event. The one exception is the system
  disconnecting the scene of a backgrounded app and reconnecting it on return — the armed
  flag lives in the process-wide singleton while the views are rebuilt, so the fresh
  `.task` loads and the (legitimate) resume event both run. Model-layer request
  coalescing is what keeps that cheap, see known gaps.
- Do not add an `initial:` parameter to `onBecomeActive`. That reintroduces the bug.

## Details worth knowing

- **A transient interruption does not count.** On iOS the app must actually reach
  `.background`. Pulling down a notification banner or control center goes
  `.active → .inactive → .active` and does not refresh. This was deliberate — those
  interruptions are frequent and a full app-wide refetch is too expensive for them.
- **`initial: true` on the central observer only arms in a fresh process.** The initial
  evaluation cannot fire the event at cold launch because the flag starts unarmed, and it
  is load-bearing for background launches (the app refreshes when the user brings it up).
  But the flag is process-global while the observer is scene-local, so the guarantee does
  not hold across scene or window teardown — see known issues.
- **Why not `UIApplication.willEnterForegroundNotification`?** Considered and rejected:
  in scene-based apps it also fires during cold launch (only legacy non-scene apps get
  launch silence), so observing it would reintroduce the launch double-fetch as a timing
  race.
- **macOS counts losing window focus** as leaving the foreground, so switching to another
  app and back refreshes. That matches the pre-existing macOS behaviour.
- **Seeded data is not fetched data.** The calendar sheets seed a model with a partial
  payload from the calendar endpoint. `SeriesEpisodes` tracks `fetchedSeriesId` so those
  seeded items do not satisfy `fetched()` and get backfilled by `.task`. Previews that
  want fully-formed data use `seed(_:)`, which marks it fetched.

## Known issues

Found by a scenario review of the mechanism (2026-08-06); fixes are planned but not
yet applied. The core single-window iPhone paths — cold launch, killed→relaunch,
suspend→resume, transient interruptions — all verified correct.

- **iPad multi-window misfires.** Multi-scene is enabled (Xcode's generated scene
  manifest), so each window installs its own observer and they all drive the one armed
  flag. A window backgrounding or closing arms it even though the app never left the
  foreground; a later `.inactive → .active` blip on a surviving window (control center,
  app-switcher peek) then fires a spurious app-wide refresh. Planned fix: move the iOS
  observer to the `App` struct, where `scenePhase` is documented to aggregate all
  scenes (`.background` only when every scene is backgrounded).
- **The armed flag outlives the views.** The flag lives in the process-wide singleton;
  the observers and `.task` state live in scenes. When the system tears down the scene
  of a backgrounded app and reconnects it (iOS memory reclaim), or a closed macOS
  window is reopened from the Dock, the rebuilt views run `.task` and then receive the
  still-armed event — a duplicate fetch, and on macOS the reopened window's
  `initial: true` pass itself can fire it.
- **macOS cold launch is probably not silent.** `appearsActive` is likely `false`
  during the initial evaluation (Apple does not document the initial value), which arms
  the flag; the window becoming key then fires it — a spurious refresh right after the
  `.task` loads. Not worse than the previous behavior, but against the stated intent.
  Both macOS items point at the same fix: drive `Lifecycle` from `AppDelegateMac`'s
  `applicationDidResignActive`/`applicationDidBecomeActive` instead of window focus.
- **`SeriesEpisodes.maybeFetch` joins across series.** The single-flight task is not
  keyed by series: push series X, pop, push series Y while X's fetch is still in flight
  on a slow instance — Y joins X's task, never issues its own fetch, and Y's season
  lists X's episodes (`bySeasonId` filters by season number only) with no self-heal
  until a resume or pull-to-refresh. Planned fix: track the in-flight series id and
  only join a matching fetch.
- **macOS sleep or screen lock with the app frontmost may never transition
  `appearsActive`** (unverified), which would mean no refresh on wake. Needs an
  on-device check before acting on it.

## Known gaps

The trigger is only one of several entry points into the same fetches — `.task`,
`.refreshable`, and instance switching hit them too. `SeriesEpisodes.maybeFetch` coalesces
concurrent callers, but the movie and series library fetches do not, and the `lastFetch`
throttle stamp is set by `fetchMoviesThrottled` and not by `fetchMoviesWithMetadata`. A
resume with a detail view open can still issue overlapping requests for the same endpoint —
with the series/season/episode stack installed, one resume fires up to three concurrent
episode fetches, since the resume reloads call `fetch(_:)` directly rather than a joinable
path. Fixing that belongs in the model layer, and needs an explicit force path so
pull-to-refresh keeps reaching the instance.
