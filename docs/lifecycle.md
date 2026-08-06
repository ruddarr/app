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

| Platform | Observer             | Signal                                             |
| -------- | -------------------- | -------------------------------------------------- |
| iOS      | `Ruddarr` App struct | `scenePhase` (App-level: aggregate of all scenes)  |
| macOS    | `AppDelegateMac`     | `applicationDidResignActive`/`DidBecomeActive`     |

The observer calls `resignedActive()` when the app leaves the foreground and
`becameActive()` when it returns. `becameActive()` only fires if it was armed first, so
a cold launch — which never left the foreground — stays silent.

Both observers deliberately sit at the app level, not in a view. App-level `scenePhase`
is documented to be `.background` only when *every* scene is backgrounded, so on iPadOS
one window closing or backgrounding never arms the flag while another window keeps the
app in the foreground. macOS app activation is similarly unambiguous where window focus
is not: closing and reopening the window, or dismissing panels, is not a resign/become
cycle.

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
- **Background launches still refresh on first foregrounding.** On iOS, `initial: true`
  on the App-level observer arms the flag when the app launches into `.background`; on
  macOS, `applicationDidFinishLaunching` arms when `NSApp.isActive` is false (e.g. a
  login item). In a fresh, normally-foregrounded launch neither path arms, so the event
  stays silent at cold start.
- **Why not `UIApplication.willEnterForegroundNotification`?** Considered and rejected:
  in scene-based apps it also fires during cold launch (only legacy non-scene apps get
  launch silence), so observing it would reintroduce the launch double-fetch as a timing
  race. macOS is different: `NSApplicationDelegate`'s resign/become-active pair has the
  arm/fire structure built into its semantics, which is why the delegate is used there.
- **macOS counts app deactivation** — switching to another app and back refreshes.
  Window focus changes within the app (panels, sheets) do not.
- **Seeded data is not fetched data.** The calendar sheets seed a model with a partial
  payload from the calendar endpoint. `SeriesEpisodes` tracks `fetchedSeriesId` so those
  seeded items do not satisfy `fetched()` and get backfilled by `.task`. Previews that
  want fully-formed data use `seed(_:)`, which marks it fetched.

## Known issues

Found by a scenario review of the mechanism (2026-08-06). The core single-window
iPhone paths — cold launch, killed→relaunch, suspend→resume, transient interruptions —
verified correct, as did iPad multi-window and the macOS launch/reopen family after
the observers moved to the app level.

- **A resume that coincides with view reinstallation still double-fetches.** If the
  system disconnected the scene while the app was backgrounded, the reconnect rebuilds
  the views (`.task` runs) and then delivers the legitimate resume event. Rare, low
  cost, and the remedy is the model-layer coalescing described under known gaps — not
  more lifecycle machinery.
- **macOS sleep or screen lock with the app frontmost may not deactivate the app**
  (unverified), which would mean no refresh on wake. Needs an on-device check before
  acting on it.

## Known gaps

The trigger is only one of several entry points into the same fetches — `.task`,
`.refreshable`, and instance switching hit them too. `SeriesEpisodes.maybeFetch` coalesces
concurrent same-series callers, but the movie and series library fetches do not coalesce. A
resume with a detail view open can still issue overlapping requests for the same endpoint —
with the series/season/episode stack installed, one resume fires up to three concurrent
episode fetches, since the resume reloads call `fetch(_:)` directly rather than a joinable
path. Fixing that belongs in the model layer, and needs an explicit force path so
pull-to-refresh keeps reaching the instance.
