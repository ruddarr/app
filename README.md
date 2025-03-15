# Ruddarr

Ruddarr is a beautifully designed, open source, companion app for Radarr and Sonarr instances written in SwiftUI.

- [App Store](https://apps.apple.com/app/ruddarr/id6476240130)
- [Join the Discord](https://discord.gg/UksvtDQUBA)

## Features

- Manage movies and TV series
- Browse upcoming releases in the calendar
- Receive fine-grained notifications
- View activity queue tasks and history events
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

To build the app locally Xcode must be signed into an Apple Account:

```
Xcode → Settings → Accounts
```

Next, select the Apple Account's team for the `Ruddarr` and `NotificationService` targets:

```
Ruddarr → Signing & Capabilities → Targets → {target} -> Signing -> Team
```

Lastly, remove the `iCloud` and `Push Notification` capabilities from:

```
Ruddarr → Signing & Capabilities → Targets → Ruddarr
```

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
