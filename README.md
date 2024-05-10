# Ruddarr

A native companion app for Radarr and Sonarr instances written in SwiftUI.

- [Ruddarr on the App Store](https://apps.apple.com/app/ruddarr/id6476240130)
- [Ruddarr TestFlight Beta](https://testflight.apple.com/join/WbWNuoos)

## Notifications

The notifications are powered by a [Cloudflare Worker](https://github.com/ruddarr/apns-worker).

## URL Schemes

### Open Screens

```
ruddarr://open
ruddarr://movies
ruddarr://series
ruddarr://calendar

ruddarr://{movies,series}/search
ruddarr://{movies,series}/search/{query}
```

## Sentry Symbols

Create a `.sentryclirc` file:

```yml
[auth]
token=sntrys_eyJp...
```

## Reset Xcode

```bash
sudo xcode-select -s /Applications/Xcode.app
xcrun simctl --set previews delete all
```
