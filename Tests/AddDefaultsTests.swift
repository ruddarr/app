import Testing
import Foundation

// Exercises `AddDefaults`, which resolves the stored movie/series add defaults against the
// quality profiles and root folders an instance currently offers. Shared by `MovieForm`,
// `SeriesForm` and the Add Movie / Add Series App Intents.
struct AddDefaultsQualityProfileTests {
    @Test func keepsPreferredProfileWhenAvailable() {
        #expect(AddDefaults.qualityProfile(4, in: [1, 4, 6]) == 4)
    }

    @Test func fallsBackToFirstProfileWhenPreferredIsMissing() {
        #expect(AddDefaults.qualityProfile(9, in: [1, 4, 6]) == 1)
    }

    // Stored defaults start out as `-1` until something was added.
    @Test func fallsBackToFirstProfileForUnsetDefault() {
        #expect(AddDefaults.qualityProfile(-1, in: [3, 4]) == 3)
        #expect(AddDefaults.qualityProfile(nil, in: [3, 4]) == 3)
    }

    @Test func returnsZeroWithoutProfiles() {
        #expect(AddDefaults.qualityProfile(4, in: []) == 0)
        #expect(AddDefaults.qualityProfile(nil, in: []) == 0)
    }
}

struct AddDefaultsRootFolderTests {
    @Test func keepsPreferredFolderWhenAvailable() {
        #expect(AddDefaults.rootFolder("/movies/4k", in: ["/movies", "/movies/4k"]) == "/movies/4k")
    }

    @Test func stripsTrailingSlashesFromPreferredFolder() {
        #expect(AddDefaults.rootFolder("/movies/4k//", in: ["/movies", "/movies/4k"]) == "/movies/4k")
    }

    // Radarr/Sonarr may report root folders with a trailing slash.
    @Test func matchesAvailableFoldersWithTrailingSlash() {
        #expect(AddDefaults.rootFolder("/movies/4k", in: ["/movies/", "/movies/4k/"]) == "/movies/4k")
    }

    // The fallback is the first folder exactly as the instance reports it.
    @Test func fallsBackToFirstFolderWhenPreferredIsMissing() {
        #expect(AddDefaults.rootFolder("/old", in: ["/movies/", "/movies/4k"]) == "/movies/")
    }

    // Stored defaults start out as an empty string until something was added.
    @Test func fallsBackToFirstFolderForUnsetDefault() {
        #expect(AddDefaults.rootFolder("", in: ["/movies"]) == "/movies")
        #expect(AddDefaults.rootFolder(nil, in: ["/movies"]) == "/movies")
    }

    @Test func keepsPreferredFolderWithoutAvailableFolders() {
        #expect(AddDefaults.rootFolder("/movies/", in: []) == "/movies")
        #expect(AddDefaults.rootFolder(nil, in: []) == nil)
    }

    // A first folder without a path offers no fallback.
    @Test func keepsPreferredFolderWhenFirstFolderHasNoPath() {
        #expect(AddDefaults.rootFolder("/old", in: [nil, "/movies"]) == "/old")
    }
}
