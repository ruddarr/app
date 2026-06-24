# AGENTS.md

Guidance for AI agents working in this repository.

## Project

- Open and build `Ruddarr.xcodeproj`. Use the shared `Ruddarr` scheme for normal app builds and tests.
- The app supports iOS, iPadOS, macOS, and visionOS-style iPhone/iPad execution through the existing Xcode settings. Do not change deployment targets, supported platforms, signing, or bundle identifiers unless the task explicitly requires it.

## Ground rules

1. **Ask, don't assume.** If something is unclear, ask before writing a single
   line. Never make silent assumptions about intent, architecture, or requirements.
2. **Simplest solution first.** Always implement the simplest thing that could
   work. Do not add abstractions or flexibility that weren't explicitly requested.
3. **Don't touch unrelated code.** If a file or function is not directly part of
   the current task, do not modify it, even if you think it could be improved.
4. **Flag uncertainty explicitly.** If you are not confident about an approach or
   technical detail, say so before proceeding. Confidence without certainty causes
   more damage than admitting a gap.
5. **I'm always open to ideas on better ways to do things.** Don't hesitate to
   suggest a better way, or one that has long-lasting impact over a tactical change.

## Conventions

- Target iOS/macOS 26+ and Swift 6.4 features, functions and conventions for app code.
- Prefer SwiftUI-native patterns and the existing dependency/mock structure under `Ruddarr/Dependencies`.
- Respect the existing SwiftLint configuration in `.swiftlint.yml`. Do not introduce a separate formatting style.
- Preserve `.xcstrings` string catalog structure. Be careful with generated or Crowdin-managed localization data.
- Use existing preview fixtures in `Ruddarr/Preview Content` before adding new mock data.
- **User-facing changes must add a `TestFlight/WhatToTest.en-US.txt` entry**. Docs, CI, and tooling-only changes don't need one.

## Build and test

CI runs iOS tests with:
```bash
xcodebuild test -scheme Ruddarr -skipPackagePluginValidation -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO MACOSX_DEPLOYMENT_TARGET=26.0
```

CI runs macOS tests with:
```bash
xcodebuild test -scheme Ruddarr -skipPackagePluginValidation -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO MACOSX_DEPLOYMENT_TARGET=26.0
```

CodeQL's Swift build uses:
```bash
xcodebuild build -scheme Ruddarr -skipPackagePluginValidation -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO MACOSX_DEPLOYMENT_TARGET=26.0
```

## Xcode hygiene

- Keep `project.pbxproj` changes focused. When files move or new Swift files are added, verify target membership and review the diff for unrelated signing or ordering churn.
- Do not commit `xcuserdata`, DerivedData, local schemes, or other machine-specific Xcode state.

## Signing and capabilities

- Local app builds may require an Apple Account and a selected team for `Ruddarr` and `NotificationService`.
- Prefer the README's local-development workaround over changing committed entitlements, signing settings, or personal provisioning state.
