import json
from faker import Faker
from random import choice, choices, randint, uniform, random
from datetime import datetime, timezone

faker = Faker()

def generate_movie_rating():
    return {
        "votes": randint(0, 10000),
        "value": uniform(0, 10)
    }

def generate_movie_ratings():
    return {
        "imdb": generate_movie_rating(),
        "tmdb": generate_movie_rating(),
        "metacritic": generate_movie_rating(),
        "rottenTomatoes": generate_movie_rating()
    }

def generate_movie_media_info():
    audio_codecs = ["AAC", "DTS", "AC3", "MP3"]
    video_codecs = ["H.264", "H.265", "VP9"]
    resolutions = ["720p", "1080p", "4K"]
    video_dynamic_ranges = ["SDR", "HDR", "Dolby Vision"]
    subtitles = ["English", "Spanish", "French", "None"]

    return {
        "audioCodec": choice(audio_codecs),
        "audioChannels": round(uniform(1.0, 7.1), 1),
        "videoCodec": choice(video_codecs),
        "resolution": choice(resolutions),
        "videoDynamicRange": choice(video_dynamic_ranges),
        "subtitles": choice(subtitles)
    }

def generate_movie_quality_info():
    qualities = [("SD", 480), ("HD", 720), ("Full HD", 1080), ("4K", 2160)]
    selected_quality = choice(qualities)

    return {
        "quality": {
            "name": selected_quality[0],
            "resolution": selected_quality[1]
        }
    }

def generate_movie_languages():
    languages = ["English", "Spanish", "French", "German", "Japanese"]
    return [{"name": language} for language in choices(languages, k=randint(1, 3))]

def generate_movie_file():
    return {
        "mediaInfo": generate_movie_media_info() if faker.boolean() else None,
        "quality": generate_movie_quality_info(),
        "languages": generate_movie_languages()
    }

def generate_movie():
    status_choices = ['tba', 'announced', 'inCinemas', 'released', 'deleted']
    status = choice(status_choices)

    return {
        "id": randint(1, 100000),
        "tmdbId": randint(1, 100000),
        "imdbId": faker.bothify(text='tt#######'),

        "title": faker.sentence(nb_words=4, variable_nb_words=True),
        "sortTitle": faker.sentence(nb_words=4, variable_nb_words=True),
        "studio": faker.company(),
        "year": randint(1950, 2024),
        "runtime": randint(60, 240),
        "overview": faker.text(max_nb_chars=200),
        "certification": choice(["G", "PG", "PG-13", "R", "NC-17"]),
        "youTubeTrailerId": faker.bothify(text='???????'),

        "alternateTitles": [{"title": faker.sentence(nb_words=4, variable_nb_words=True)} for _ in range(randint(0, 20))],

        "genres": [faker.word() for _ in range(randint(1, 5))],
        "ratings": generate_movie_ratings(),
        "popularity": uniform(0, 100),

        "status": status,
        "minimumAvailability": status,

        "monitored": faker.boolean(),
        "qualityProfileId": randint(1, 5),
        "sizeOnDisk": randint(0, 10000000000),
        "hasFile": faker.boolean(),
        "isAvailable": faker.boolean(),

        "path": faker.file_path(depth=5),
        "folderName": faker.word(),
        "rootFolderPath": faker.file_path(depth=2),

        "added": faker.date_time_this_century(tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "inCinemas": faker.date_time_this_decade(tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "physicalRelease": faker.date_time_this_year(tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "digitalRelease": faker.date_time_this_month(tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),

        "images": [{"coverType": choice(["cover", "background"]), "remoteURL": faker.image_url(), "url": faker.image_url()} for _ in range(randint(1, 3))],
        "movieFile": generate_movie_file() if faker.boolean() else None,
    }

movies = [generate_movie() for _ in range(5000)]

json_output = json.dumps(movies, indent=4)

print(json_output)
