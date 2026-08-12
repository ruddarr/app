# iPhone Landscape Readiness

Tracking checklist for enabling landscape orientation on iPhone (in preparation
for larger iPhone form factors). iPad has always supported all orientations;
macOS is a native, freely-resizable target and is unaffected.

Apple's direction (WWDC25/WWDC26): supported orientations become a *preference*
that is ignored in resizable environments (iPhone apps on iPad, iPhone
Mirroring). Layout decisions should be driven by size classes and container
geometry — never by device idiom, orientation, or screen bounds. Landscape
iPhone means compact *height*; large iPhones report a **regular** horizontal
size class in landscape.

## Done

- [x] Allow `LandscapeLeft`/`LandscapeRight` on iPhone (`project.pbxproj`,
  `INFOPLIST_KEY_UISupportedInterfaceOrientations`) — no `PortraitUpsideDown`,
  per Apple guidance for Face ID devices
- [x] Details poster: size off the window's short side, capped at 200pt, so it
  keeps its portrait size in landscape instead of growing past the visible
  height (`Ruddarr/Models/Media.swift`, `MediaDetailsPosterModifier`)

## High priority

- [ ] Sheets in compact height: the system ignores partial detents and presents
  sheets full-height in iPhone landscape. Visually verify each sheet and add a
  `verticalSizeClass` case to `DynamicPresentationDetents`
  (`Ruddarr/Utilities/View.swift`) — it is the single funnel for all detents.
  Affected: quick-look previews (`.fraction(0.33)`), activity/calendar
  (`.fraction(0.7)`), releases (`.medium`), and siblings
- [ ] Migrate layout branches from `deviceType == .phone` to size classes
  (pattern: `Ruddarr/Services/WhatsNew.swift:167-211`), starting with:
  - [ ] `MovieDetails.swift:31` / `SeriesDetails.swift:29` (actions placement)
  - [ ] `MovieDetails+Overview.swift` / `SeriesDetails+Overview.swift`
    (labels, fonts, sizes)
  - [ ] `Views/Shared/InformationList.swift:9` (list vs. 3-column grid)

  Keep `deviceType` for genuinely device-bound behavior (haptics, wording,
  macOS chrome).

## Medium

- [ ] Context-menu previews use a fixed 300×450pt frame, taller than any iPhone
  in landscape (`MovieGridPoster.swift`, `MovieGridCard.swift`, Series
  equivalents) — cap by available height or size class
- [ ] `descriptionTruncated` is initialized once in `onAppear` from idiom
  (`MovieDetails.swift:61`, `SeriesDetails.swift:63`, `EpisodeView.swift:185`)
  and never re-evaluates on rotation

## Low / polish

- [ ] `WhatsNew.swift:73` uses deprecated `.edgesIgnoringSafeArea(.bottom)`;
  footer background does not extend into the horizontal safe-area insets that
  landscape introduces
- [ ] `Discovery.swift:20,26` caps discovery results at 24 on phones — a
  portrait-capacity heuristic
- [ ] Instance picker toolbar placement is idiom-gated
  (`MoviesView.swift:86`, `SeriesView.swift:89`)

## Product decisions (open)

- [ ] History tab is iPad-only (`ContentView.swift:29`). Should it appear
  whenever a regular-width layout is active (large iPhone in landscape), or
  stay iPad-only?
- [ ] `.tabBarMinimizeBehavior(.never)` (`ContentView.swift:45`): consider
  `.onScrollDown` in compact height, where the pinned tab bar consumes a large
  share of the ~400pt viewport

## Decisions taken

- iOS grid posters stay small: `MediaGrid` keeps the phone metrics
  (100–130pt adaptive columns) in both orientations — landscape simply shows
  more columns. Do not switch grids to iPad-class metrics on iPhone.
- The details poster is capped at 200pt on all iOS devices, matching iPad, so
  poster sizing stays uniform across orientations and form factors.

## Testing

- [ ] Every screen in landscape, rotating both left and right (asymmetric
  sensor-housing insets)
- [ ] Squarish ~4:3 canvases via Xcode resizable simulator / Live Preview
  resize handles
- [ ] Forms with keyboard up in compact height (instance settings, search)
- [ ] iPhone app on iPad and iPhone Mirroring (resizable environments where
  the orientation preference is ignored)
