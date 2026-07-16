# Episode jump: disappearing navigation title

## Problem

Jumping to an episode via the `↗` "Open" button in the Calendar episode sheet
(or from a queue task) randomly left the navigation bar title blank on the
episode screen — sometimes it never appeared, sometimes it showed briefly and
then vanished. It was not tied to a specific show or instance.

## Cause

The jump navigated in two stages:

1. `SeriesView.navigateToSeries` set the navigation path to
   `[.series, .season]`.
2. `SeasonView` fetched the episodes in its `.task`, then appended `.episode`
   to the path once it resolved the episode number from the deeplink.

On a fast instance the episode fetch returns within milliseconds, so the
second push started while the first transition — plus the tab switch and the
calendar sheet dismissal — was still animating. Pushing mid-transition can
desync the navigation bar from the navigation stack, and since `EpisodeView`
is the only view in the series stack that sets a `navigationTitle`, any
desync rendered as a blank bar. Whether the title survived depended on where
in the animation window the second push landed, hence the randomness.

## Fix

`navigateToSeries` now resolves the episode up front (`resolveEpisode`
fetches the episodes and matches by series, season, and episode number) and
sets the complete path `[.series, .season, .episode]` in a single assignment.
The jump becomes one settled transition with nothing left to race — and lands
directly on the episode instead of hopping through the season.

If the episode cannot be resolved (fetch failure, unknown number), the old
behavior remains as a fallback: the path ends at `.season(..., episodeId)`
and `SeasonView`'s `jumpToEpisode` relay pushes the episode when it appears.
Season-only jumps (grouped calendar entries) are unaffected.

## Code

- `Ruddarr/Views/SeriesView.swift` — `navigateToSeries`, `resolveEpisode`
- `Ruddarr/Views/Series/SeasonView.swift` — `maybeNavigateToEpisode` (fallback)
