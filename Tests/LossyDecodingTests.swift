import Testing
import Foundation

// Exercises `decodeLossyArrayIfPresent` in Ruddarr/Utilities/LossyDecoding.swift,
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
