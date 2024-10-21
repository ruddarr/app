# Ruddarr

Ruddarr is a beautifully designed, open source, companion app for Radarr and Sonarr instances written in SwiftUI.

- [Ruddarr on the App Store](https://apps.apple.com/app/ruddarr/id6476240130)
- [Ruddarr TestFlight Beta](https://testflight.apple.com/join/WbWNuoos)
- [Ruddarr on Discord](https://discord.gg/UksvtDQUBA)

## Features

- Manage movies and TV series
- Browse upcoming releases in the calendar
- Receive fine-grained notifications
- Switch between multiple instances
- Customize the app color scheme and appearance
- Synchronize settings/instances between devices (iCloud)
- Automate actions using Siri Shortcuts
- Connect to reverse proxies using custom HTTP headers
- Use Spotlight search to quickly jump to media
- Fully localized, ready to be translated

## Localization

Help [translate Ruddarr](https://crowdin.com/project/ruddarr) into other languages. Check the `#translators` channel [on Discord](https://discord.gg/UksvtDQUBA)

## Notifications

The code of the notification service is powered by a Cloudflare Worker and also [open source](https://github.com/ruddarr/apns-worker).

## URL Schemes

Ruddarr supports the `ruddarr://` URL Scheme to open specific tabs, items or perform actions. All supported schemes are listed in the [`QuickActions.swift`](https://github.com/ruddarr/app/blob/develop/Ruddarr/Dependencies/QuickActions.swift)

## Development

### Sentry Symbols

Create a `.sentryclirc` file:

```yml
[auth]
token=sntrys_eyJp...
```

### Reset Xcode

```bash
sudo xcode-select -s /Applications/Xcode.app
xcrun simctl --set previews delete all
```
