import Testing
import Foundation

// Exercises `decodeLossyArrayIfPresent` in Ruddarr/Utilities/Decoders.swift,
// used by MediaFile.init so a null array element (e.g. Sonarr's `"languages": [null]`)
// drops out instead of failing the whole response.
struct LossyDecodingTests {
    private struct Element: Codable, Equatable {
        let id: Int
        let name: String?
    }

    private struct Fixture: Codable, Equatable {
        let items: [Element]?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            items = try container.decodeLossyArrayIfPresent([Element].self, forKey: .items)
        }
    }

    private func decode(_ json: String) throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: Data(json.utf8))
    }

    @Test func dropsNullElement() throws {
        // The exact shape from the episodeFile crash report.
        #expect(try decode(#"{"items": [null]}"#).items == [])
    }

    @Test func keepsValidElementsAroundNulls() throws {
        let items = try decode(#"{"items": [{"id": 1, "name": "English"}, null, {"id": 2, "name": null}]}"#).items
        #expect(items == [Element(id: 1, name: "English"), Element(id: 2, name: nil)])
    }

    @Test func decodesNormalArrayUnchanged() throws {
        let items = try decode(#"{"items": [{"id": 1, "name": "English"}, {"id": 2, "name": "German"}]}"#).items
        #expect(items == [Element(id: 1, name: "English"), Element(id: 2, name: "German")])
    }

    @Test func decodesEmptyArray() throws {
        #expect(try decode(#"{"items": []}"#).items == [])
    }

    @Test func missingKeyDecodesToNil() throws {
        #expect(try decode(#"{}"#).items == nil)
    }

    @Test func explicitNullValueDecodesToNil() throws {
        #expect(try decode(#"{"items": null}"#).items == nil)
    }
}

// Exercises `LenientDecoded`, used by `Episode.episodeFile` so a malformed
// embedded file degrades to nil instead of failing the whole episodes response.
struct LenientDecodedTests {
    private struct File: Codable, Equatable {
        let id: Int
        let size: Int
    }

    private struct Fixture: Codable, Equatable {
        let id: Int
        @LenientDecoded var file: File?
    }

    private func decode(_ json: String) throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: Data(json.utf8))
    }

    @Test func decodesValidValue() throws {
        let fixture = try decode(#"{"id": 1, "file": {"id": 7, "size": 42}}"#)
        #expect(fixture.file == File(id: 7, size: 42))
    }

    @Test func missingKeyDecodesToNil() throws {
        #expect(try decode(#"{"id": 1}"#).file == nil)
    }

    @Test func explicitNullDecodesToNil() throws {
        #expect(try decode(#"{"id": 1, "file": null}"#).file == nil)
    }

    @Test func malformedValueDecodesToNil() throws {
        #expect(try decode(#"{"id": 1, "file": {"id": 7, "size": "big"}}"#).file == nil)
        #expect(try decode(#"{"id": 1, "file": {"id": 7}}"#).file == nil)
        #expect(try decode(#"{"id": 1, "file": 3}"#).file == nil)
    }

    @Test func siblingFieldsStayStrict() throws {
        #expect(throws: DecodingError.self) {
            try self.decode(#"{"id": "one", "file": {"id": 7, "size": 42}}"#)
        }
    }

    @Test func encodingOmitsNil() throws {
        let data = try JSONEncoder().encode(Fixture(id: 1, file: nil))
        #expect(String(bytes: data, encoding: .utf8) == #"{"id":1}"#)
    }

    @Test func roundTripsValue() throws {
        let fixture = Fixture(id: 1, file: File(id: 7, size: 42))
        let decoded = try JSONDecoder().decode(Fixture.self, from: JSONEncoder().encode(fixture))
        #expect(decoded == fixture)
    }
}
