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

## Screenshots
<p>
  <a href="https://github.com/user-attachments/assets/9b8e1509-88e4-49f8-a22d-c30b0dc8f2db"><img src="https://github.com/user-attachments/assets/9b8e1509-88e4-49f8-a22d-c30b0dc8f2db" alt="Movies library" width="24%"></a>
  <a href="https://github.com/user-attachments/assets/ad590837-15bf-4f17-b35d-33b33959eb53"><img src="https://github.com/user-attachments/assets/ad590837-15bf-4f17-b35d-33b33959eb53" alt="Series details" width="24%"></a>
  <a href="https://github.com/user-attachments/assets/b6c5c15f-e508-48fc-80f0-2429307f3419"><img src="https://github.com/user-attachments/assets/b6c5c15f-e508-48fc-80f0-2429307f3419" alt="Calendar" width="24%"></a>
  <a href="https://github.com/user-attachments/assets/576de4dc-0e6f-4816-8d65-b62142fe8b80"><img src="https://github.com/user-attachments/assets/576de4dc-0e6f-4816-8d65-b62142fe8b80" alt="Discover movies" width="24%"></a>
</p>

## Localization

Help [translate Ruddarr](https://crowdin.com/project/ruddarr) into any language. Check the `#translators` channel [on Discord](https://discord.gg/UksvtDQUBA). Unfortunately, [some messages](https://github.com/ruddarr/app/issues/433) cannot be translated by Ruddarr.

## Notifications

The code of the notification service is and also [open source](https://github.com/ruddarr/apns-worker).

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

Now choose between **a)** creating a provisioning profile on your account for the `iCloud`, `App Groups` and `Push Notification` capabilities and skipping the next steps, or **b)** continuing on and removing the capabilities from both targets (the `NotificationService` target only has `App Groups`):

```
Ruddarr → Signing & Capabilities → Targets → Ruddarr
Ruddarr → Signing & Capabilities → Targets → NotificationService
```

Then uncomment the CloudKit mock in `Ruddarr::init()`:

```swift
dependencies.cloudkit = .mock
```

> [!NOTE]
> Instances and other settings are stored in the `group.com.ruddarr` App Group so app extensions can read them. When using your own bundle identifier, update `Ruddarr.group` in `Ruddarr.swift` and the `App Groups` entry in both the `Ruddarr` and `NotificationService` entitlements to match.

That's it. Select a run destination and build it. 

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
