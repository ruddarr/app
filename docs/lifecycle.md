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
installed after the event fired never see it, which is what makes the duplicate
impossible rather than merely unlikely.

## Rules for call sites

- Initial load goes in `.task`.
- Refresh-on-resume goes in `.onBecomeActive()`.
- A view that needs both uses both. They cannot overlap: `.task` runs on installation,
  `onBecomeActive` only on a resume event.
- Do not add an `initial:` parameter to `onBecomeActive`. That reintroduces the bug.

## Details worth knowing

- **A transient interruption does not count.** On iOS the app must actually reach
  `.background`. Pulling down a notification banner or control center goes
  `.active → .inactive → .active` and does not refresh. This was deliberate — those
  interruptions are frequent and a full app-wide refetch is too expensive for them.
- **`initial: true` on the central observer is safe** and is load-bearing for background
  launches. The initial evaluation can only ever *arm* the flag (`becameActive()` no-ops
  when unarmed), so an app launched into the background still refreshes when the user
  brings it up.
- **macOS counts losing window focus** as leaving the foreground, so switching to another
  app and back refreshes. That matches the pre-existing macOS behaviour.
- **Seeded data is not fetched data.** The calendar sheets seed a model with a partial
  payload from the calendar endpoint. `SeriesEpisodes` tracks `fetchedSeriesId` so those
  seeded items do not satisfy `fetched()` and get backfilled by `.task`. Previews that
  want fully-formed data use `seed(_:)`, which marks it fetched.

## Known gaps

The trigger is only one of several entry points into the same fetches — `.task`,
`.refreshable`, and instance switching hit them too. `SeriesEpisodes.maybeFetch` coalesces
concurrent callers, but the movie and series library fetches do not, and the `lastFetch`
throttle stamp is set by `fetchMoviesThrottled` and not by `fetchMoviesWithMetadata`. A
resume with a detail view open can still issue overlapping requests for the same endpoint.
Fixing that belongs in the model layer, and needs an explicit force path so
pull-to-refresh keeps reaching the instance.
