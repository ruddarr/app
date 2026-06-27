# Changelog

All notable changes to Ruddarr are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Added
- Display download queue status in various places
- Show "Downloading" instead of "Missing" on downloading episode rows
- Switched to sheets for calendar navigation
- Added quick look preview to media posters
- Added "History" to sidebar on iPadOS
- Display disk space usage and statistics for instances
- Display counts below media grids

### Changed
- Animate discovery grid loading indicator
- Improved byte formatting precision in some places
- Improved image loading performance
- Improved media grid sorting/filtering performance
- Improved performance of loading movie files
- Debounce library search queries
- Removed sidebar header on iPadOS
- Refined sections in settings view
- Various internal code improvements

### Fixed
- Fixed sidebar colors on macOS 27
- Fixed blurry discovery headline on iPadOS

## 1.8.3 - 2026-06-23
### Added
- Added Brazilian Portuguese localization
- Added episode links to Callsheet
- Added support for downgrade notifications

### Changed
- Improved calendar filtering/ordering
- Clarified search placeholder text

### Fixed
- Fixed broken Trakt links
- Fixed poster size when screen sharing
- Fixed negative custom format scores double minus sign
- Fixed missing top padding on media info sheet on macOS
- Fixed iOS 26.4+ toolbar crash
- Fixed various small iOS 27 issues

## 1.8.2 - 2026-05-15
### Added
- Added Norwegian localization

### Changed
- Avoid showing discovery grid for fresh Sonarr instances

### Fixed
- Fixed language label for Multilingual releases

## 1.8.1 - 2026-04-09
### Added
- Added Italian and Turkish translations

### Changed
- Calendar: Fade unmonitored items
- Discovery: Fade items already in library
- Discovery: Improved loading contrast
- Releases: Include dual audio releases in "Multilingual" filter
- Calendar: Improved loading and error handling
- Show fewer error dialogues
- Improved detection of and feedback about local ip addresses
- Improved loading of season episode list
- Various internal code improvements and bug fixes

### Removed
- Removed Chinese translation (abandoned)

### Fixed
- Fixed sheet titles when "Reduce Transparency" is enabled

## 1.8.0 - 2026-02-25
### Added
- Added "Popular This Week" section
- Restored native macOS app for TestFlight
- Allow filtering media by root folder
- Allow monitoring movie collections when adding

### Changed
- Improved handling of non-https instances
- Made elevator music less invasive
- Updated "Podcasts" theme color
- Show media title in some cases while poster is loading
- Improved notification webhook logic
- Various design and internal code improvements

### Fixed
- Fixed checking series monitoring status in calendar
- Fixed "Missing" being red when episode is not monitored
- Fixed translation issue of open app shortcut

## 1.7.2 - 2025-12-02
### Added
- Allow iPad version to run on macOS

### Changed
- Improved button/sheet styling for iOS 26.1
- Update notification webhooks more frequently
- Several minor improvements and fixes

## 1.7.1 - 2025-10-12
### Changed
- Adjust spacing on media info sheet
- Don't minimize tab bar when scrolling on iOS

### Fixed
- Fixed Radarr instance switching on iOS

## 1.7.0 - 2025-10-05
### Added
- Support deleting season episodes

### Changed
- Switched to Liquid Glass design
- Improved instance switchers
- Show file size on media sheet
- Duck elevator music
- Animate queue changes
- Switched to native toolbars for sheets
- Update instance tags more frequently

### Fixed
- Fixed release filter freeze
- Fixed alert tinting
- Fixed current date not updating in calendar

## 1.6.1 - 2025-09-08
### Added
- Added basic support for managing tags for media
- Added Chinese translation

### Changed
- Permanently disable elevator music with a triple tap
- Reset search query when starting new release search
- Made "no releases" messages more helpful
- Show byte size on `grabbed` event sheet
- Several minor improvements and fixes

### Fixed
- Fixed poor phase change handling

## 1.6.0 - 2025-06-02
### Added
- Added card-style views for media grids
- Added support for importing files of pending queue tasks
- Added notifications for media/file deletion
- Added quality to upgrade notifications (broken in TestFlight)
- Support hiding specials in calendar

### Changed
- Collapse season pack queue tasks
- Collapse episodes bundles in calendar
- Various minor UX improvements
- Improve launching app from a suspended state

### Fixed
- Attempt to fix crash when searching for series
- Fixed re-rendering issue on iOS 18.4+
- Fixed rare crash with invalid instance urls

## 1.5.2 - 2025-04-28
### Changed
- Refactored media deletion action

### Fixed
- Fixed media grid jumping

## 1.5.1 - 2025-04-24
### Changed
- Disable confusing button with identical text
- Made media grid scrolling a little smoother
- Internal improvements and code cleanup

### Fixed
- Fixed freezing during interactive searches
- Fixed logic of "search for replacement" toggle

## 1.5.0 - 2025-04-09
### Added
- Added German, French and Spanish translations

### Changed
- Made releases searchable
- Improved translatability and text scalability
- Avoid initial Calendar scroll
- Dozens of small internal improvements and fixes

### Fixed
- Fixed calendar scrolling issues
- Fixed issues with bug report sheet
- Fixed freeze during interactive searches
- Try to avoid rare bindable crash
- Removed bottom gap from release lists

## 1.4.3 - 2025-03-17
### Added
- Added preference option to persist release search filters

### Changed
- Scroll to "Today" when tapping calendar tab
- Various internal improvements

### Fixed
- Fixed crash on some devices when trying to render media poster

## 1.4.2 - 2025-03-11
### Changed
- Show loading indicator for more action buttons
- Animate more state changes around the app
- Improved release loading messages
- Replaced support email with bug report sheet
- Several internal improvements and fixes

### Fixed
- Attempt to resolve series view crash
- Fixed rare crash due to missing environment object

## 1.4.1 - 2025-02-28
### Added
- Highlight today's episode in episode list

### Changed
- Refresh calendar when resuming app
- Redesigned settings icons
- Throttled fetching media when displaying grid
- Improved stability

### Fixed
- Fixed several crashes

## 1.4.0 - 2024-12-09
### Added
- Added History list in Activity tab
- Jump directly to episode from notifications and calendar events
- Show ratings for TV Series
- Allow queue error messages to be selected

### Changed
- Upgraded codebase to Swift 6
- Persist "Monitored" filter in Calendar
- Fetch episodes after changing season monitoring
- Fetch instance metadata faster
- Refresh data when switching to app
- Update events after refreshing calendar data
- Extract IMDB identifier when searching library
- Reset calendar events after modifying instances
- Improved calendar error handling
- Improved layout of release sheets
- Improved wording around the app
- Improved notification webhook error handling

### Fixed
- Fixed poster icons for existing series in search list
- Fixed episode toolbar monitor button
- Fixed calendar date not updating
- Fixed noun used for Sonarr history event descriptions
- Fixed setting default app icon
- Fixed `/activity` deeplink

## 1.3.1 - 2024-11-04
### Added
- Show bitrate estimations for files and releases
- Filter calendar entries by instance
- Suggest search for new media when searching local library

### Changed
- Switch to instance when notification is opened
- Fetch calendar events and series episodes/files in parallel
- Improved handling of queue task with warnings
- Improved queue task and media file sheet layouts
- Increased timeout for interactive release searches
- Dismiss task sheet when task is completed
- Strip season folder from file names
- Improved rendering series with thousands of episodes
- Improved download client detection
- Improved some wording around the app

### Fixed
- Fixed searching for releases again after switching tabs
- Fixed API call to blacklist movie when deleting
- Fixed delay before rendering queue task list
- Fixed queue item sheet displaying stale data
- Fixed displaying irrelevant history events
- Fixed transparent tab background when adding media
- Fixed refresh not fetching episode history events
- Fixed some history event labels
- Fixed several crashes

## 1.3.0 - 2024-10-23
### Added
- Support cancelling queue tasks
- Support long-pressing links to open in Chrome/Firefox
- Filter queue tasks by protocol/client and releases by multilingual
- Sort media by rating
- Show tips about monitoring, deleting files and automatic searches
- Suggest opening Sable/DSLoad for relevant queue tasks

### Changed
- Switch to iOS 18 `TabView` for better navigation
- Improved Spotlight indexer performance
- Refresh download client data faster when viewing Activity
- Keep search results on screen when navigating
- Improved webhook event support and error handling
- Dozens of other improvements and minor fixes

### Fixed
- Fixed setting app icon
- Fixed edge cases when determining movie status
- Fixed monitoring episode button logic
- Fixed many crashes across the app
- Fixed search actions appearing in "Open In…" menus

## 1.2.1 - 2024-10-03
### Added
- Added series search scopes
- Added `ManualInteractionRequired` webhook events
- Added "Search Monitored" button on iPad
- Support starting from Activity tab and `ruddarr://activity` calls
- Parse IMDb links when pasting or using URL scheme
- Enabled visionOS builds

### Changed
- Index alternative titles and large instances in Spotlight
- Show value of selected release filter
- Unified titles of notifications
- Don't ask for reviews for at least a week
- Don't format season numbers
- Show loading animation when monitoring season
- Reset filter values when starting release search
- Show filter note below release list
- Show more subtitles and media size on iPad
- Revert to default `TabView` without custom overlay
- Capture API response when decoding error occurs

### Removed
- Removed translations temporarily

### Fixed
- Fixed several issues with Spotlight integration
- Fixed display of icon inside the app
- Fixed Sonarr release indexer flags display
- Fixed displaying release language
- Fixed calendar error overlay issue

## 1.2.0 - 2024-09-16
### Added
- Added "Activity" tab for queue and history
- Added Spotlight integration
- Added iOS 18 app icon styles
- Added French and Spanish translations
- Added setting for initial launch tab
- Support grabbing unmapped releases
- Support adding exclusion when deleting media
- Support disabling health warning notifications
- Support automatic search from context menus
- Support Callsheet links for TV series
- Support sorting movies by grab date
- Ask for App Store reviews

### Changed
- Reworked and localized Siri Shortcuts
- Fade in posters when scrolling
- Show posters in notifications
- Various calendar improvements and fixes
- Improved handling of slow *arr searches
- Improved loading of season episodes
- Remember choices when adding media
- Preserve search path when adding media
- Show episode resolution in episode list
- Improve handling of expired TestFlight subscriptions
- Disabled auto-correct for search fields
- Use larger sheet when adding media on iPad
- Use builtin formatter for "runtime" numbers
- Use builtin localized string for language code lookup
- Center episode list progress indicator
- Display releases without enough peers in red

### Removed
- Removed "Calendar" quick action

### Fixed
- Fixed displaying stale series releases
- Fixed missing Sonarr task state and event types
- Fixed episode monitoring issue
- Fixed some media not showing when searching library
- Fixed Basic Authentication alert disappearing
- Fixed displaying stale release search results
- Fixed "Next airing" sort direction
- Fixed Root Folder picker changing colors
- Fixed multiline text alignment in "Information" rows
- Fixed dozens of decoding errors and improved reporting
- Fixed display of history event date

## 1.1.0 - 2024-05-21
### Added
- Added support for Sonarr instances
- Allow filtering releases by "Original" language
- Allow sorting movies by digital release date
- Added helpful some "Reset Filter" buttons
- Added helpful badge on "filters" icon when selected
- Support deleting individual files

### Changed
- Switched to native macOS app
- Improved results when sorting by "Year"
- Three dozens of small improvements, refinements and bug fixes

### Fixed
- Fixed issue displaying the wrong date in the calendar
- Fixed "Missing" filter conditions and the "Title" sort direction
- Fixed scrolling lagging at times
- Fixed pull-to-refresh from being cancelled

## 1.0.3 - 2024-05-03
### Added
- Support filtering releases by language
- Added "Large Instance" Mode
- Link to movie form from "Information" values

### Changed
- Hide advanced instance settings initially
- Show "What's New" when first launching app
- Show title when editing movie
- Show notification status for each instance
- Made poster icons smaller and the gradient gentler
- Switched the logic of "Wanted" and "Missing" filters
- Moved license acknowledgements to settings
- Various minor internal improvements

### Fixed
- Fixed Sonarr v3 authentication (calendar only)
- Fixed subtitles list display issue

## 1.0.2 - 2024-04-28
### Added
- Allow sorting by "File Size" and filtering by "Downloaded"

### Changed
- Improved performance for large libraries
- Show title when movie has no poster
- Consider movies without a year unreleased

### Fixed
- Fixed file size calculation
- Fixed a couple of decoding errors and rare crashes
- Fixed various issues when sorting releases
- Fixed triggering initial movie search
- Fixed rare video resolution display issue
- Fixed subtitle and language lists alignment

## 1.0.1 - 2024-04-24
### Added
- Support instance URLs with paths
- Split up "About" section into new "Community" section

### Changed
- Show movie title instead of blank placeholder image
- Improved "Root Folder" picker
- Switched to alerts instead of confirmation dialog for iPad compatibility
- Close sidebar after tapping item on iPad in portrait mode

### Fixed
- Fixed "Share App" link in App Store build
- Fixed disappearing "Delete Movie" confirmation dialog

## 1.0.0 - 2024-04-24
### Added
- Initial release
