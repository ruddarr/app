import Testing
import Foundation

// Covers `RequestDiagnostics` — the in-memory ring buffer behind the "Failed Requests" diagnostics
// section: newest-first ordering, keyed duplicate collapsing (a repeat replaces its older entry at
// the head with a fresh date), and the 50-entry cap. The actor is Foundation-only (the `API.Error`
// → `Reason` mapping lives in `API+Error.swift`, an app-only file), so these can construct
// `FailedRequest.Reason` values directly.
struct RequestDiagnosticsTests {
    @Test func recordsNewestFirst() async {
        let store = RequestDiagnostics()

        await store.record(method: "GET", url: "https://a", instance: "Radarr", reason: .status(code: 500, message: nil))
        await store.record(method: "POST", url: "https://b", instance: "Sonarr", reason: .transport("boom"))

        let entries = await store.snapshot()

        #expect(entries.count == 2)
        #expect(entries[0].url == "https://b")
        #expect(entries[1].url == "https://a")
    }

    @Test func collapsesRepeatedIdenticalFailures() async {
        let store = RequestDiagnostics()

        for _ in 0..<5 {
            await store.record(method: "GET", url: "https://a", instance: nil, reason: .transport("offline"))
        }

        let entries = await store.snapshot()

        #expect(entries.count == 1)
    }

    @Test func duplicateMovesToTheFrontWithAFreshEntry() async {
        let store = RequestDiagnostics()

        await store.record(method: "GET", url: "https://a", instance: nil, reason: .transport("offline"))
        await store.record(method: "GET", url: "https://b", instance: nil, reason: .transport("offline"))

        let before = await store.snapshot()

        await store.record(method: "GET", url: "https://a", instance: nil, reason: .transport("offline"))

        let entries = await store.snapshot()

        #expect(entries.count == 2)
        #expect(entries[0].url == "https://a")
        #expect(entries[1].url == "https://b")
        #expect(entries[0].id != before[1].id)
        #expect(entries[0].date >= before[1].date)
    }

    @Test func distinguishesByReason() async {
        let store = RequestDiagnostics()

        await store.record(method: "GET", url: "https://a", instance: nil, reason: .status(code: 500, message: nil))
        await store.record(method: "GET", url: "https://a", instance: nil, reason: .status(code: 502, message: nil))

        let entries = await store.snapshot()

        #expect(entries.count == 2)
    }

    @Test func distinguishesByInstance() async {
        let store = RequestDiagnostics()

        await store.record(method: "GET", url: "https://a", instance: "Radarr", reason: .transport("offline"))
        await store.record(method: "GET", url: "https://a", instance: "Sonarr", reason: .transport("offline"))

        let entries = await store.snapshot()

        #expect(entries.count == 2)
    }

    @Test func capsAtFiftyKeepingNewest() async {
        let store = RequestDiagnostics()

        for index in 0..<60 {
            await store.record(method: "GET", url: "https://host/\(index)", instance: nil, reason: .transport("e"))
        }

        let entries = await store.snapshot()

        #expect(entries.count == 50)
        #expect(entries.first?.url == "https://host/59")
        #expect(entries.last?.url == "https://host/10")
    }

    @Test func blankInstanceBecomesNil() async {
        let store = RequestDiagnostics()

        await store.record(method: "GET", url: "https://a", instance: "", reason: .transport("e"))

        let entries = await store.snapshot()

        #expect(entries.first?.instance == nil)
    }

    @Test func clearRemovesEverything() async {
        let store = RequestDiagnostics()

        await store.record(method: "GET", url: "https://a", instance: nil, reason: .transport("e"))
        await store.clear()

        let entries = await store.snapshot()

        #expect(entries.isEmpty)
    }
}
