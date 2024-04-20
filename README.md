# Ruddarr

A native iOS companion app for Radarr and Sonarr instances.

## URL Schemes

### Open Screens

```
ruddarr://open
ruddarr://movies
ruddarr://calendar
```

### Search Movies

```
ruddarr://movies/search
ruddarr://movies/search/{query}
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
