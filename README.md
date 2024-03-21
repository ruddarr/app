# Ruddarr

A companion app for Radarr and Sonarr instances. Browse libraries, manage content and search for new content.

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

## Radarr Demo

You can either use `dependencies = .mock` in `Ruddarr.swift` or use this demo server for testing.

Host: `http://167.172.20.216:7878`
Username: `ruddarr`
Password: `password`
API Key: `b3216ceaa69341619b1b56377607972c`

### Server

```bash
ssh root@167.172.20.216

docker run -d \
  --name=radarr \
  -e PUID=0 \
  -e PGID=0 \
  -e TZ=Etc/UTC \
  -p 7878:7878 \
  -v /root/radarr-data:/config \
  -v /root/radarr-movies:/movies  \
  -v /root/radarr-downloads:/downloads \
  --restart unless-stopped \
  lscr.io/linuxserver/radarr:latest
```

```bash
curl --request POST \
  --url 'https://api.letterboxd.com/api/v0/auth/token' \
  --header 'accept: application/json' \
  --header 'content-type: application/x-www-form-urlencoded' \
  --data grant_type=client_credentials \
  --data client_id=a8cabc7a-d963-454f-8757-69788adb432e \
  --data client_secret=XhFUbf9MA7HwqsamD84n6SBLGK5NduJkgjYxTPVpeR2QtvZE \
  --data audience=YOUR_API_IDENTIFIER
```

curl -X "POST" "https://api.letterboxd.com/api/v0/auth/token" \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' \
     --data-urlencode "grant_type=password" \
     --data-urlencode "username=a8cabc7a-d963-454f-8757-69788adb432e" \
     --data-urlencode "password=XhFUbf9MA7HwqsamD84n6SBLGK5NduJkgjYxTPVpeR2QtvZE"
