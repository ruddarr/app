# Ruddarr

A companion app for Radarr and Sonarr instances. Browse libraries, manage content and search for new content.

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
