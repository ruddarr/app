import Testing
import Foundation

struct CustomFilterTests {
    private struct Item: CustomFilterable {
        static var customFilterValues: [String: @Sendable (Item) -> CustomFilterItemValue?] {
            let keys = ["monitored", "title", "studio", "year", "rating", "genres", "tags", "added", "nextAiring"]
            return Dictionary(uniqueKeysWithValues: keys.map { key in (key, { @Sendable item in item.values[key] }) })
        }

        var values: [String: CustomFilterItemValue]
    }

    private let now = Date(timeIntervalSince1970: 1_718_452_800)

    private var item: Item {
        Item(values: [
            "monitored": .bool(true),
            "title": .string("The Matrix"),
            "year": .number(1_999),
            "rating": .decimal(7.3, scale: 10),
            "genres": .strings(["Action", "Science Fiction"]),
            "tags": .numbers([1, 42]),
            "added": .date(now.addingTimeInterval(-10 * 86_400)),
            "nextAiring": .date(nil),
        ])
    }

    private func filter(_ json: String) throws -> CustomFilter {
        try JSONDecoder().decode(CustomFilter.self, from: Data(#"{"id": 1, "type": "test", "label": "Test", "filters": \#(json)}"#.utf8))
    }

    private func matches(_ key: String, _ type: String, _ value: String) throws -> Bool {
        try filter(#"[{"key": "\#(key)", "type": "\#(type)", "value": \#(value)}]"#).matches(item, now: now)
    }

    @Test func decodesServerFilters() throws {
        let json = #"[{"id": 7, "type": "movieIndex", "label": "4K", "filters": [{"key": "tags", "value": [2, 5], "type": "contains"}, "#
            + #"{"key": "added", "value": {"time": "days", "value": null}, "type": "inLast"}, {"key": "monitored", "value": [true]}]}]"#
        let filters = try JSONDecoder().decode([CustomFilter].self, from: Data(json.utf8))

        #expect(filters[0].id == 7)
        #expect(filters[0].filters[0].value == .array([.number(2), .number(5)]))
        #expect(filters[0].filters[1].value == .object(["time": .string("days"), "value": .null]))
        #expect(filters[0].filters[2].operator == .equal)

        let encoded = try JSONEncoder().encode(filters[0])
        #expect(try JSONDecoder().decode(CustomFilter.self, from: encoded) == filters[0])
    }

    @Test func dropsUndecodableFilters() throws {
        let json = #"[{"id": 1, "type": "movieIndex", "label": "Good", "filters": []}, "#
            + #"{"id": "2", "type": "movieIndex", "label": "Bad id", "filters": []}, "#
            + #"{"id": 3, "type": "movieIndex", "label": "No key", "filters": [{"value": [1]}]}]"#
        let filters = try JSONDecoder().decode([LossyDecoded<CustomFilter>].self, from: Data(json.utf8))

        #expect(filters.compactMap(\.wrappedValue).map(\.id) == [1])
    }

    @Test func supportsKnownKeysAndOperators() throws {
        #expect(try filter(#"[{"key": "year", "value": [1999], "type": "equal"}]"#).isSupported(for: Item.self))
        #expect(try !filter(#"[{"key": "keywords", "value": ["heist"], "type": "contains"}]"#).isSupported(for: Item.self))
        #expect(try !filter(#"[{"key": "year", "value": [1999], "type": "between"}]"#).isSupported(for: Item.self))
    }

    @Test func requiresEveryCondition() throws {
        let both = #"[{"key": "monitored", "value": [true], "type": "equal"}, {"key": "year", "value": [1999], "type": "equal"}]"#
        let either = #"[{"key": "monitored", "value": [true], "type": "equal"}, {"key": "year", "value": [2000], "type": "equal"}]"#

        #expect(try filter(both).matches(item, now: now))
        #expect(try !filter(either).matches(item, now: now))
    }

    @Test func equalMatchesAnyValueAndNotEqualEvery() throws {
        #expect(try matches("year", "equal", "[1998, 1999]"))
        #expect(try !matches("year", "notEqual", "[1998, 1999]"))
        #expect(try matches("year", "notEqual", "[1998, 2000]"))
        #expect(try !matches("year", "equal", #"["1999"]"#))
        #expect(try !matches("title", "equal", #"["the matrix"]"#))
    }

    @Test func containsChecksArraysAndStrings() throws {
        #expect(try matches("tags", "contains", "[5, 42]"))
        #expect(try !matches("tags", "notContains", "[5, 42]"))
        #expect(try matches("tags", "notContains", "[5, 6]"))
        #expect(try matches("genres", "contains", #"["Action"]"#))
        #expect(try !matches("genres", "contains", #"["action"]"#))
        #expect(try matches("title", "contains", #"["MATRIX"]"#))
        #expect(try matches("title", "notContains", #"["Matrices"]"#))
    }

    @Test func checksPrefixesAndSuffixes() throws {
        #expect(try matches("title", "startsWith", #"["the "]"#))
        #expect(try matches("title", "endsWith", #"["RIX"]"#))
        #expect(try matches("title", "notStartsWith", #"["Matrix"]"#))
        #expect(try !matches("title", "notEndsWith", #"["Matrix"]"#))
    }

    @Test func comparesNumbers() throws {
        #expect(try matches("year", "greaterThan", "[1998]"))
        #expect(try matches("year", "greaterThanOrEqual", "[1999]"))
        #expect(try !matches("year", "lessThan", "[1999]"))
        #expect(try matches("year", "lessThanOrEqual", "[1999]"))
        #expect(try matches("rating", "equal", "[73]"))
    }

    @Test func comparesDates() throws {
        #expect(try matches("added", "lessThan", #""2024-06-10""#))
        #expect(try !matches("added", "greaterThan", #""2024-06-10""#))
        #expect(try matches("added", "greaterThan", #""2024-06-01""#))

        #expect(try matches("added", "inLast", #"{"time": "weeks", "value": 2}"#))
        #expect(try !matches("added", "inLast", #"{"time": "days", "value": 7}"#))
        #expect(try matches("added", "notInLast", #"{"time": "days", "value": 7}"#))
        #expect(try !matches("added", "inNext", #"{"time": "months", "value": 1}"#))
    }

    @Test func missingValuesNeverMatch() throws {
        #expect(try !matches("nextAiring", "notInLast", #"{"time": "days", "value": 7}"#))
        #expect(try !matches("studio", "notEqual", #"["Warner Bros."]"#))
        #expect(try !matches("keywords", "contains", #"["heist"]"#))
    }
}
