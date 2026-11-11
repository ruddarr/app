// swiftlint:disable file_length
import Testing
import Foundation

// Exercises the custom filter wire format and the web UI's evaluation rules
// (Ruddarr/Models/CustomFilters). `Movie`/`Series` can't be compiled into this test bundle,
// so the rules run against `Item`, a fixture with the same kinds of values.
struct CustomFilterTests {
    // MARK: - Fixtures

    private struct Item: CustomFilterable {
        static let customFilterType = "test"
        static var customFilterHiddenKeys: Set<String> { ["missing"] }
        static var customFilterFields: [CustomFilterField] {
            [
                .init(key: "monitored", label: "Monitored", builder: .exact, kind: .bool),
                .init(key: "status", label: "Status", builder: .exact, kind: .options([])),
                .init(key: "title", label: "Title", builder: .string, kind: .text),
                .init(key: "studio", label: "Studio", builder: .exact, kind: .libraryValues),
                .init(key: "year", label: "Year", builder: .number, kind: .number),
                .init(key: "rating", label: "Rating", builder: .number, kind: .number),
                .init(key: "genres", label: "Genres", builder: .array, kind: .libraryValues),
                .init(key: "tags", label: "Tags", builder: .array, kind: .tag),
                .init(key: "added", label: "Added", builder: .date, kind: .date),
                .init(key: "nextAiring", label: "Next Airing", builder: .date, kind: .date),
            ]
        }

        var values: [String: CustomFilterItemValue]

        func customFilterValue(for key: String) -> CustomFilterItemValue {
            values[key] ?? .unsupported
        }
    }

    // 2024-06-15 12:00 UTC, evaluated in a fixed UTC-5 time zone.
    private let now = Date(timeIntervalSince1970: 1_718_452_800)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -5 * 3_600)!
        return calendar
    }()

    private let item = Item(values: [
        "monitored": .bool(true),
        "status": .string("released"),
        "title": .string("The Matrix"),
        "studio": .missing,
        "year": .number(1_999),
        "rating": .decimal(7.3, scale: 10),
        "genres": .strings(["Action", "Science Fiction"]),
        "tags": .numbers([1, 42]),
        "added": .date(Date(timeIntervalSince1970: 1_718_452_800 - 10 * 86_400)),
        "nextAiring": .date(nil),
        "missing": .result(true),
    ])

    private func filter(_ conditions: CustomFilterCondition...) -> CustomFilter {
        CustomFilter(id: .app(UUID()), label: "Test", conditions: conditions)
    }

    private func matches(_ key: String, _ value: CustomFilterValue, _ type: String, _ item: Item? = nil) -> Bool {
        filter(CustomFilterCondition(key: key, value: value, type: type))
            .matches(item ?? self.item, now: now, calendar: calendar)
    }

    private func decode(_ json: String) throws -> CustomFilterResource {
        try JSONDecoder().decode(CustomFilterResource.self, from: Data(json.utf8))
    }

    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try #require(String(bytes: encoder.encode(value), encoding: .utf8))
    }

    // MARK: - Wire format

    @Test func decodesSpecExamples() throws {
        let radarr = try decode(#"""
        { "id": 4, "type": "movieIndex", "label": "Recent 4K picks", "filters": [
          { "key": "monitored", "value": [true], "type": "equal" },
          { "key": "qualityProfileId", "value": [6], "type": "equal" },
          { "key": "added", "value": { "time": "days", "value": 30 }, "type": "inLast" },
          { "key": "tags", "value": [2, 5], "type": "contains" },
          { "key": "imdbRating", "value": [7.5], "type": "greaterThanOrEqual" }
        ] }
        """#)

        #expect(radarr.customFilter?.id == .server(4))
        #expect(radarr.type == "movieIndex")
        #expect(radarr.label == "Recent 4K picks")
        #expect(radarr.filters.map(\.value) == [
            .array([.bool(true)]),
            .array([.int(6)]),
            .object(["time": .string("days"), "value": .int(30)]),
            .array([.int(2), .int(5)]),
            .array([.double(7.5)]),
        ])
        #expect(radarr.filters[2].operator == .inLast)

        let bigOld = try decode(#"""
        { "id": 7, "type": "movieIndex", "label": "Big old non-horror", "filters": [
          { "key": "releaseDate", "value": "2000-01-01", "type": "lessThan" },
          { "key": "genres", "value": ["Horror", "Comedy"], "type": "notContains" },
          { "key": "sizeOnDisk", "value": [21474836480], "type": "greaterThan" },
          { "key": "status", "value": ["released"], "type": "equal" }
        ] }
        """#)

        #expect(bigOld.filters[0].value == .string("2000-01-01"))
        #expect(bigOld.filters[2].value == .array([.int(21_474_836_480)]))

        let sonarr = try decode(#"""
        { "id": 2, "type": "series", "label": "Anime gaps", "filters": [
          { "key": "status", "value": ["continuing", "upcoming"], "type": "equal" },
          { "key": "seriesType", "value": ["anime"], "type": "equal" },
          { "key": "hasMissingSeason", "value": [true], "type": "equal" },
          { "key": "seasonsMonitoredStatus", "value": ["all"], "type": "equal" },
          { "key": "title", "value": ["the"], "type": "notStartsWith" }
        ] }
        """#)

        #expect(sonarr.filters.count == 5)
        #expect(sonarr.filters[0].value == .array([.string("continuing"), .string("upcoming")]))
        #expect(sonarr.filters[4].operator == .notStartsWith)
    }

    @Test func missingTypeMeansEqualAndMissingValueMeansNull() throws {
        let resource = try decode(#"{ "id": 1, "type": "movieIndex", "label": "A", "filters": [{ "key": "monitored" }] }"#)

        #expect(resource.filters[0].type == "equal")
        #expect(resource.filters[0].value == .null)
    }

    @Test func encodingPreservesIntsUnknownOperatorsAndUnsupportedConditions() throws {
        let json = #"{"filters":["#
            + #"{"key":"tags","type":"contains","value":[2,5]},"#
            + #"{"key":"keywords","type":"contains","value":["heist"]},"#
            + #"{"key":"year","type":"betweenish","value":[1.5]}"#
            + #"],"id":3,"label":"A","type":"movieIndex"}"#

        #expect(try encode(decode(json)) == json)
    }

    @Test func encodingANewFilterOmitsTheId() throws {
        let filter = CustomFilter(id: .app(UUID()), label: "New", conditions: [
            CustomFilterCondition(key: "qualityProfileId", value: .array([.int(4)]), operator: .equal),
        ])

        let json = try encode(CustomFilterResource(filter, type: "series"))

        #expect(json == #"{"filters":[{"key":"qualityProfileId","type":"equal","value":[4]}],"label":"New","type":"series"}"#)
    }

    @Test func customFilterRoundTripsThroughTheCache() throws {
        let original = CustomFilter(id: .app(UUID()), label: "Mine", conditions: [
            CustomFilterCondition(key: "added", value: .object(["time": .string("weeks"), "value": .null]), operator: .inLast),
            CustomFilterCondition(key: "custom", value: .array([.bool(false)]), type: "someFutureOperator"),
        ])

        let decoded = try JSONDecoder().decode(CustomFilter.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)

        let server = CustomFilter(id: .server(9), label: "Theirs", conditions: [])
        #expect(try JSONDecoder().decode(CustomFilter.self, from: JSONEncoder().encode(server)) == server)
    }

    @Test func lossyListDropsMalformedEntries() throws {
        let json = #"""
        [
          { "id": 1, "type": "movieIndex", "label": "Good", "filters": [] },
          { "id": 2, "type": "movieIndex", "label": "No filters" },
          { "id": 3, "type": "history", "label": "Other", "filters": [{ "key": "eventType", "value": 4 }] }
        ]
        """#

        let filters = try JSONDecoder().decode([LossyDecoded<CustomFilterResource>].self, from: Data(json.utf8))
            .compactMap(\.wrappedValue)

        #expect(filters.map(\.id) == [1, 3])
    }

    // MARK: - Filter loop

    @Test func emptyFilterMatchesEverything() {
        #expect(filter().matches(item, now: now, calendar: calendar))
    }

    @Test func conditionsAreANDed() {
        let both = filter(
            CustomFilterCondition(key: "monitored", value: .array([.bool(true)]), operator: .equal),
            CustomFilterCondition(key: "year", value: .array([.int(2_000)]), operator: .lessThan)
        )
        let one = filter(
            CustomFilterCondition(key: "monitored", value: .array([.bool(true)]), operator: .equal),
            CustomFilterCondition(key: "year", value: .array([.int(1_990)]), operator: .lessThan)
        )

        #expect(both.matches(item, now: now, calendar: calendar))
        #expect(!one.matches(item, now: now, calendar: calendar))
    }

    @Test func arrayValuesNeedAnyElementForPositiveOperators() {
        #expect(matches("tags", .array([.int(7), .int(42)]), "contains"))
        #expect(!matches("tags", .array([.int(7), .int(8)]), "contains"))
        #expect(matches("status", .array([.string("tba"), .string("released")]), "equal"))
        #expect(matches("year", .array([.int(2_010), .int(1_990)]), "greaterThan"))
    }

    @Test func arrayValuesNeedEveryElementForNegativeOperators() {
        #expect(matches("genres", .array([.string("Horror"), .string("Comedy")]), "notContains"))
        #expect(!matches("genres", .array([.string("Horror"), .string("Action")]), "notContains"))
        #expect(matches("status", .array([.string("tba"), .string("deleted")]), "notEqual"))
        #expect(!matches("status", .array([.string("tba"), .string("released")]), "notEqual"))
    }

    @Test func emptyArrayRejectsPositiveAndAcceptsNegativeOperators() {
        #expect(!matches("tags", .array([]), "contains"))
        #expect(!matches("status", .array([]), "equal"))
        #expect(matches("tags", .array([]), "notContains"))
        #expect(matches("status", .array([]), "notEqual"))
    }

    @Test func scalarValuesAreTestedOnce() {
        #expect(matches("monitored", .bool(true), "equal"))
        #expect(!matches("monitored", .bool(false), "equal"))
        #expect(matches("tags", .int(42), "contains"))
    }

    // MARK: - Generic predicates

    @Test func equalityIsStrict() {
        #expect(!matches("tags", .array([.string("1")]), "contains"))
        #expect(!matches("year", .array([.string("1999")]), "equal"))
        #expect(!matches("monitored", .array([.string("true")]), "equal"))
        #expect(!matches("monitored", .array([.int(1)]), "equal"))
        #expect(matches("monitored", .array([.string("true")]), "notEqual"))
        #expect(matches("year", .array([.double(1_999.0)]), "equal"))
        #expect(matches("tags", .array([.double(42.0)]), "contains"))
    }

    @Test func stringEqualityIsCaseSensitive() {
        #expect(matches("title", .array([.string("The Matrix")]), "equal"))
        #expect(!matches("title", .array([.string("the matrix")]), "equal"))
        #expect(matches("title", .array([.string("the matrix")]), "notEqual"))
    }

    @Test func substringOperatorsAreCaseInsensitive() {
        #expect(matches("title", .array([.string("MATRIX")]), "contains"))
        #expect(!matches("title", .array([.string("matrix")]), "notContains"))
        #expect(matches("title", .array([.string("the")]), "startsWith"))
        #expect(!matches("title", .array([.string("the")]), "notStartsWith"))
        #expect(matches("title", .array([.string("RIX")]), "endsWith"))
        #expect(matches("title", .array([.string("neo")]), "notEndsWith"))
        #expect(matches("title", .array([.string("")]), "contains"))
    }

    @Test func itemArraysUseStrictMembership() {
        #expect(matches("genres", .array([.string("Action")]), "contains"))
        #expect(!matches("genres", .array([.string("action")]), "contains"))
        #expect(!matches("genres", .array([.string("Science")]), "contains"))
    }

    @Test func stringOperatorsOnNonStringsFail() {
        // The web UI throws on `toLowerCase`, so the condition fails either way.
        #expect(!matches("year", .array([.int(19)]), "startsWith"))
        #expect(!matches("year", .array([.int(19)]), "notStartsWith"))
        #expect(!matches("title", .array([.int(1)]), "contains"))
        #expect(!matches("title", .array([.int(1)]), "notContains"))
    }

    @Test func numberComparisons() {
        #expect(matches("year", .array([.int(1_999)]), "greaterThanOrEqual"))
        #expect(!matches("year", .array([.int(1_999)]), "greaterThan"))
        #expect(matches("year", .array([.int(1_999)]), "lessThanOrEqual"))
        #expect(matches("year", .array([.int(2_000)]), "lessThan"))
        #expect(matches("year", .array([.int(1_998)]), "notEqual"))
    }

    @Test func ratingsAreScaledByTen() {
        #expect(matches("rating", .array([.int(73)]), "equal"))
        #expect(matches("rating", .array([.int(70)]), "greaterThan"))
        #expect(!matches("rating", .array([.int(74)]), "greaterThanOrEqual"))
        #expect(CustomFilterItemValue.decimal(0, scale: 10).isNumber(0))
    }

    // MARK: - Item values

    @Test func missingValuesRejectTheItem() {
        #expect(!matches("studio", .array([.string("Warner")]), "equal"))
        #expect(!matches("studio", .array([.string("Warner")]), "notEqual"))
        #expect(!matches("studio", .array([]), "notContains"))
    }

    @Test func unsupportedValuesFailTheCondition() {
        #expect(!matches("keywords", .array([.string("heist")]), "contains"))
        #expect(!matches("keywords", .array([.string("heist")]), "notContains"))
    }

    @Test func resultValuesIgnoreValueAndOperator() {
        #expect(matches("missing", .array([.bool(false)]), "equal"))
        #expect(matches("missing", .bool(true), "notEqual"))
        #expect(!matches("missing", .array([.bool(true)]), "equal", Item(values: ["missing": .result(false)])))
        // The predicate still runs once per element, so an empty array follows the array rules.
        #expect(!matches("missing", .array([]), "equal"))
        #expect(matches("missing", .array([]), "notEqual", Item(values: ["missing": .result(false)])))
    }

    @Test func unknownOperatorsFail() {
        #expect(!matches("title", .array([.string("The Matrix")]), "fuzzyEquals"))
    }

    // MARK: - Dates

    @Test func absoluteDatesAreLocalMidnightAndStrict() {
        // 2024-06-05 05:00 UTC is exactly local midnight on June 5 in UTC-5.
        let midnight = Item(values: ["added": .date(Date(timeIntervalSince1970: 1_717_563_600))])

        #expect(!matches("added", .string("2024-06-05"), "lessThan", midnight))
        #expect(!matches("added", .string("2024-06-05"), "greaterThan", midnight))
        #expect(matches("added", .string("2024-06-06"), "lessThan", midnight))
        #expect(matches("added", .string("2024-06-04"), "greaterThan", midnight))

        let justBefore = Item(values: ["added": .date(Date(timeIntervalSince1970: 1_717_563_599))])
        #expect(matches("added", .string("2024-06-05"), "lessThan", justBefore))
    }

    @Test func relativeDates() {
        let last30 = CustomFilterValue.object(["time": .string("days"), "value": .int(30)])
        let last7 = CustomFilterValue.object(["time": .string("days"), "value": .int(7)])

        // `added` is 10 days ago.
        #expect(matches("added", last30, "inLast"))
        #expect(!matches("added", last7, "inLast"))
        #expect(matches("added", last7, "notInLast"))
        #expect(!matches("added", last30, "notInLast"))
        #expect(!matches("added", last30, "inNext"))
        #expect(!matches("added", last30, "notInNext"))
        #expect(matches("added", .object(["time": .string("weeks"), "value": .int(2)]), "inLast"))
        #expect(!matches("added", .object(["time": .string("hours"), "value": .int(48)]), "inLast"))
    }

    @Test func futureDatesAreNotInLast() {
        let inFiveDays = Item(values: ["added": .date(now.addingTimeInterval(5 * 86_400))])
        let days = { (amount: Int) in CustomFilterValue.object(["time": .string("days"), "value": .int(amount)]) }

        #expect(!matches("added", days(30), "inLast", inFiveDays))
        #expect(!matches("added", days(30), "notInLast", inFiveDays))
        #expect(matches("added", days(30), "inNext", inFiveDays))
        #expect(!matches("added", days(3), "inNext", inFiveDays))
        #expect(matches("added", days(3), "notInNext", inFiveDays))
        #expect(!matches("added", days(30), "notInNext", inFiveDays))
    }

    @Test func monthsAreCalendarAware() {
        // 2024-03-31 12:00 UTC minus one month clamps to 2024-02-29 in the local calendar.
        let march31 = Date(timeIntervalSince1970: 1_711_886_400)
        let month = CustomFilterRelativeDate(unit: .months, amount: 1)
        let bound = month.date(from: march31, forward: false, calendar: calendar)

        #expect(bound == Date(timeIntervalSince1970: 1_709_208_000))
    }

    @Test func nullRelativeValueMeansZero() {
        let zero = CustomFilterValue.object(["time": .string("seconds"), "value": .null])

        #expect(matches("added", zero, "notInLast"))
        #expect(!matches("added", zero, "inLast"))
    }

    @Test func nilDatesNeverMatch() {
        let days = CustomFilterValue.object(["time": .string("days"), "value": .int(30)])

        for type in ["inLast", "notInLast", "inNext", "notInNext"] {
            #expect(!matches("nextAiring", days, type))
        }

        #expect(!matches("nextAiring", .string("2030-01-01"), "lessThan"))
        #expect(!matches("nextAiring", .string("2000-01-01"), "greaterThan"))
    }

    @Test func otherOperatorsOnDatesFail() {
        #expect(!matches("added", .string("2024-06-05"), "equal"))
    }

    // MARK: - Support

    @Test func supportedFilter() {
        let supported = filter(
            CustomFilterCondition(key: "tags", value: .array([.int(1)]), operator: .contains),
            CustomFilterCondition(key: "added", value: .object(["time": .string("months"), "value": .int(3)]), operator: .notInLast),
            CustomFilterCondition(key: "added", value: .string("2024-02-29"), operator: .greaterThan),
            CustomFilterCondition(key: "missing", value: .bool(true), operator: .equal)
        )

        #expect(supported.isSupported(for: Item.self))
    }

    @Test func unsupportedConditions() {
        let unknownKey = CustomFilterCondition(key: "keywords", value: .array([.string("heist")]), operator: .contains)
        let unknownOperator = CustomFilterCondition(key: "title", value: .array([.string("a")]), type: "fuzzy")
        let badDate = CustomFilterCondition(key: "added", value: .string("2024-02-30"), operator: .lessThan)
        let looseDate = CustomFilterCondition(key: "added", value: .string("2024-2-3"), operator: .lessThan)
        let badUnit = CustomFilterCondition(key: "added", value: .object(["time": .string("years"), "value": .int(1)]), operator: .inLast)
        let relativeOnNumber = CustomFilterCondition(key: "year", value: .object(["time": .string("days"), "value": .int(1)]), operator: .inLast)
        let objectValue = CustomFilterCondition(key: "year", value: .array([.object([:])]), operator: .equal)
        let fine = CustomFilterCondition(key: "year", value: .array([.int(2_000)]), operator: .lessThan)

        let mixed = filter(unknownKey, unknownOperator, badDate, looseDate, badUnit, relativeOnNumber, objectValue, fine)

        #expect(mixed.unsupportedConditions(for: Item.self) == [unknownKey, unknownOperator, badDate, looseDate, badUnit, relativeOnNumber, objectValue])
        #expect(!mixed.isSupported(for: Item.self))
    }

    @Test func relativeDateEncodesWholeNumbersAsInts() {
        #expect(CustomFilterRelativeDate(unit: .days, amount: 30).value == .object(["time": .string("days"), "value": .int(30)]))
        #expect(CustomFilterRelativeDate(.object(["time": .string("hours"), "value": .double(1.5)]))?.amount == 1.5)
    }
}

private extension CustomFilterItemValue {
    func isNumber(_ expected: Double) -> Bool {
        if case .number(let value) = self { return value == expected }
        return false
    }
}
