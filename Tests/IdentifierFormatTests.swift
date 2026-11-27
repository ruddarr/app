import Testing
import Foundation

// Locks the persisted identifier formats in `Identifiers.swift`.
//
// `MediaEntityID` strings are stored inside users' shortcuts (App Intents entities) and
// `SpotlightItemID` strings are stored in the on-device Spotlight index. Both outlive app
// updates, so the fixtures below must keep parsing and building exactly as they do today.
struct MediaEntityIDTests {
    private let instance = UUID(uuidString: "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8")!

    @Test func buildsShippedFormat() {
        #expect(MediaEntityID(42, instance).rawValue == "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:42")
    }

    @Test func parsesShippedFormat() {
        let id = MediaEntityID(rawValue: "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:42")

        #expect(id?.mediaId == 42)
        #expect(id?.instanceId == instance)
    }

    @Test func roundTrips() {
        for mediaId in [0, 1, 42, 100_123, Int.max] {
            let id = MediaEntityID(mediaId, instance)
            #expect(MediaEntityID(rawValue: id.rawValue) == id)
        }
    }

    // `UUID(uuidString:)` accepts lowercase, so identifiers survive a case change.
    @Test func parsesLowercaseInstance() {
        let id = MediaEntityID(rawValue: "6f1c2a3b-4d5e-4f60-8172-93a4b5c6d7e8:42")

        #expect(id == MediaEntityID(42, instance))
    }

    @Test(arguments: [
        "",
        ":",
        "42",
        "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
        "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:",
        ":42",
        "42:6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
        "not-a-uuid:42",
        "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:abc",
        "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:42:extra",
        "movie:42:6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
    ])
    func rejectsInvalidInput(_ rawValue: String) {
        #expect(MediaEntityID(rawValue: rawValue) == nil)
    }
}

struct SpotlightItemIDTests {
    private let instance = "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8"

    @Test func buildsShippedFormat() {
        #expect(SpotlightItemID(.movie, 42, instance).rawValue == "movie:42:\(instance)")
        #expect(SpotlightItemID(.series, 7, instance).rawValue == "series:7:\(instance)")
    }

    // Items of media without an instance were indexed with an empty trailing component.
    @Test func buildsShippedFormatWithoutInstance() {
        #expect(SpotlightItemID(.movie, 42, nil).rawValue == "movie:42:")
    }

    @Test func parsesShippedFormat() {
        let movie = SpotlightItemID(rawValue: "movie:42:\(instance)")
        let series = SpotlightItemID(rawValue: "series:7:\(instance)")

        #expect(movie == SpotlightItemID(.movie, 42, instance))
        #expect(series == SpotlightItemID(.series, 7, instance))
    }

    @Test func parsesMissingInstanceAsNil() {
        #expect(SpotlightItemID(rawValue: "movie:42:") == SpotlightItemID(.movie, 42, nil))
    }

    @Test func roundTrips() {
        for item in [
            SpotlightItemID(.movie, 42, instance),
            SpotlightItemID(.series, 100_123, instance),
            SpotlightItemID(.movie, 1, nil),
        ] {
            #expect(SpotlightItemID(rawValue: item.rawValue) == item)
        }
    }

    @Test(arguments: [
        "",
        "movie",
        "movie:42",
        "episode:42:6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
        "Movie:42:6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
        "movie:abc:6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
        "movie::6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8",
        "movie:42:6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:extra",
        "6F1C2A3B-4D5E-4F60-8172-93A4B5C6D7E8:42",
    ])
    func rejectsInvalidInput(_ rawValue: String) {
        #expect(SpotlightItemID(rawValue: rawValue) == nil)
    }
}
