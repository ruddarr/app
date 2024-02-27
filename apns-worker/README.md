# APNs Cloudflare Worker

## Testing

```bash
http post https://notify.ruddarr.com/_b918aa44b3801da03a12956597e93b05 \
  User-Agent:Radarr/1.0 \
  eventType=RuddarrTest instanceName=void
```

```bash
cat payloads/movie-grab.json | http post https://notify.ruddarr.com/_b918aa44b3801da03a12956597e93b05 User-Agent:Radarr/1.0
cat payloads/health-restored.json | http post https://notify.ruddarr.com/_b918aa44b3801da03a12956597e93b05 User-Agent:Radarr/1.0
cat payloads/series-download.json | http post https://notify.ruddarr.com/_b918aa44b3801da03a12956597e93b05 User-Agent:Radarr/1.0
cat payloads/movie-grab.json | http post https://notify.ruddarr.com/_b918aa44b3801da03a12956597e93b05 User-Agent:Radarr/1.0
```

### `Test`

```json
{
  "movie": {
    "id": 1,
    "title": "Test Title",
    "year": 1970,
    "releaseDate": "1970-01-01",
    "folderPath": "C:\\testpath",
    "tmdbId": 0
  },
  "remoteMovie": {
    "tmdbId": 1234,
    "imdbId": "5678",
    "title": "Test title",
    "year": 1970
  },
  "release": {
    "quality": "Test Quality",
    "qualityVersion": 1,
    "releaseGroup": "Test Group",
    "releaseTitle": "Test Title",
    "indexer": "Test Indexer",
    "size": 9999999,
    "customFormatScore": 0
  },
  "eventType": "Test",
  "instanceName": "Radarr",
  "applicationUrl": ""
}
```

### `Health`

```json
{
  "level": "warning",
  "message": "Indexers unavailable due to failures: Blutopia (API) (Prowlarr)",
  "type": "IndexerStatusCheck",
  "wikiUrl": "https://wiki.servarr.com/radarr/system#indexers-are-unavailable-due-to-failures",
  "eventType": "Health",
  "instanceName": "Radarr",
  "applicationUrl": ""
}
```

### `HealthRestored`

```json
{
  "level": "warning",
  "message": "Indexers unavailable due to failures: Blutopia (API) (Prowlarr)",
  "type": "IndexerStatusCheck",
  "wikiUrl": "https://wiki.servarr.com/radarr/system#indexers-are-unavailable-due-to-failures",
  "eventType": "HealthRestored",
  "instanceName": "Radarr"
}
```

### `MovieAdded`

```json
{
  "movie": {
    "id": 284,
    "title": "Spirited Away",
    "year": 2001,
    "releaseDate": "2002-07-19",
    "folderPath": "/volume2/Media/Movies/Spirited Away (2001)",
    "tmdbId": 129,
    "imdbId": "tt0245429",
    "overview": "A young girl, Chihiro, becomes trapped in a strange new world of spirits. When her parents undergo a mysterious transformation, she must call upon the courage she never knew she had to free her family."
  },
  "addMethod": "manual",
  "eventType": "MovieAdded",
  "instanceName": "Radarr",
  "applicationUrl": ""
}
```

### `MovieDelete`

```json
{
  "movie": {
    "id": 277,
    "title": "Crimes of the Future",
    "year": 2022,
    "releaseDate": "2022-08-09",
    "folderPath": "/volume2/Media/Movies/Crimes of the Future (2022)",
    "tmdbId": 819876,
    "imdbId": "tt14549466",
    "overview": "With his partner Caprice, celebrity performance artist Saul Tenser publicly showcases the metamorphosis of his organs in avant-garde performances. Timlin, an investigator from the National Organ Registry, obsessively tracks their movements, which is when a mysterious group is revealed... Their mission -- to use Saul's notoriety to shed light on the next phase of human evolution."
  },
  "deletedFiles": true,
  "movieFolderSize": 0,
  "eventType": "MovieDelete",
  "instanceName": "Radarr",
  "applicationUrl": ""
}
```

### `Grab`

```json
{
  "movie": {
    "id": 285,
    "title": "Akira",
    "year": 1988,
    "releaseDate": "1996-12-01",
    "folderPath": "/volume2/Media/Documentaries/Akira (1988)",
    "tmdbId": 149,
    "imdbId": "tt0094625",
    "overview": "A secret military project endangers Neo-Tokyo when it turns a biker gang member into a rampaging psychic psychopath that only two teenagers and a group of psychics can stop."
  },
  "remoteMovie": {
    "tmdbId": 149,
    "imdbId": "tt0094625",
    "title": "Akira",
    "year": 1988
  },
  "release": {
    "quality": "Bluray-1080p",
    "qualityVersion": 1,
    "releaseGroup": "KiNGDOM",
    "releaseTitle": "Akira 1988 1080p BDRip H264 AAC English Dubbed -KiNGDOM",
    "indexer": "Pirate Bay (Prowlarr)",
    "size": 4252075264,
    "customFormatScore": 0,
    "customFormats": [],
    "indexerFlags": [
      "G_Freeleech"
    ]
  },
  "downloadClient": "Download Station",
  "downloadClientType": "Download Station",
  "downloadId": "7FCF20EEAACD0F7810C11FD62E90076E9A25B76F:dbid_1234",
  "customFormatInfo": {
    "customFormats": [],
    "customFormatScore": 0
  },
  "eventType": "Grab",
  "instanceName": "Radarr",
  "applicationUrl": ""
}
```

### `Download`

```json
{
  "movie": {
    "id": 284,
    "title": "Spirited Away",
    "year": 2001,
    "releaseDate": "2002-07-19",
    "folderPath": "/volume2/Media/Movies/Spirited Away (2001)",
    "tmdbId": 129,
    "imdbId": "tt0245429",
    "overview": "A young girl, Chihiro, becomes trapped in a strange new world of spirits. When her parents undergo a mysterious transformation, she must call upon the courage she never knew she had to free her family."
  },
  "remoteMovie": {
    "tmdbId": 129,
    "imdbId": "tt0245429",
    "title": "Spirited Away",
    "year": 2001
  },
  "movieFile": {
    "id": 242,
    "relativePath": "Spirited.Away.2002.1080p.BluRay.Dual-Audio.DD+.5.1.x265-NAN0.mkv",
    "path": "/volume2/Media/#downloads/Spirited.Away.2002.1080p.BluRay.Dual-Audio.DD+.5.1.x265-NAN0.mkv",
    "quality": "Bluray-1080p",
    "qualityVersion": 1,
    "releaseGroup": "NAN0",
    "sceneName": "Spirited.Away.2002.1080p.BluRay.Dual-Audio.DD+.5.1.x265-NAN0",
    "indexerFlags": "0",
    "size": 12729205605,
    "dateAdded": "2024-02-13T03:05:31.2989497Z",
    "mediaInfo": {
      "audioChannels": 5.1,
      "audioCodec": "EAC3",
      "audioLanguages": [
        "jpn",
        "eng"
      ],
      "height": 1036,
      "width": 1920,
      "subtitles": [
        "eng"
      ],
      "videoCodec": "x265",
      "videoDynamicRange": "",
      "videoDynamicRangeType": ""
    }
  },
  "isUpgrade": false,
  "downloadClient": "Download Station",
  "downloadClientType": "Download Station",
  "downloadId": "7FCF20EEAACD0F7810C11FD62E90076E9A25B76F:dbid_1226",
  "customFormatInfo": {
    "customFormats": [],
    "customFormatScore": 0
  },
  "release": {
    "releaseTitle": "Spirited Away AKA Sen to Chihiro no Kamikakushi 2002 1080p BluRay Dual-Audio DD+ 5.1 x265-NAN0",
    "indexer": "Blutopia (API) (Prowlarr)",
    "size": 12729205760
  },
  "eventType": "Download",
  "instanceName": "Radarr",
  "applicationUrl": ""
}

```

### `ApplicationUpdate`

```json
{
    "message": "Radarr updated from 4.2.0.6370 to 4.2.0.6372",
    "previousVersion": "4.2.0.6370",
    "newVersion": "4.2.0.6372",
    "eventType": "ApplicationUpdate"
}
```
