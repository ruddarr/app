import Testing
import Foundation
@testable import Ruddarr

struct CommandsTests {
    @Test func decodesCompletedSeriesSearch() throws {
        let json = """
        {
          "id": 42,
          "name": "SeriesSearch",
          "commandName": "Series Search",
          "message": "Completed",
          "status": "completed",
          "result": "successful",
          "queued": "2026-04-05T10:15:00Z",
          "started": "2026-04-05T10:15:01Z",
          "ended": "2026-04-05T10:15:04Z",
          "trigger": "manual"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let status = try decoder.decode(InstanceCommandStatus.self, from: json)

        #expect(status.id == 42)
        #expect(status.name == "SeriesSearch")
        #expect(status.state == .completed)
        #expect(status.message == "Completed")
        #expect(status.isSearchCommand == true)
        #expect(status.isTerminal == true)
    }

    @Test func decodesQueuedCommandWithoutEndedDate() throws {
        let json = """
        {
          "id": 7,
          "name": "MoviesSearch",
          "status": "queued",
          "queued": "2026-04-05T10:00:00Z",
          "trigger": "manual"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let status = try decoder.decode(InstanceCommandStatus.self, from: json)

        #expect(status.state == .queued)
        #expect(status.ended == nil)
        #expect(status.isTerminal == false)
    }

    @Test func unknownStateFallsBack() throws {
        let json = """
        { "id": 1, "name": "Foo", "status": "warp-driving", "queued": "2026-04-05T10:00:00Z" }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let status = try decoder.decode(InstanceCommandStatus.self, from: json)
        #expect(status.state == .unknown)
        #expect(status.isSearchCommand == false)
    }

    @Test @MainActor func trackInsertsCommandAtFront() async {
        let commands = Commands.makeForTesting()
        let instanceId = UUID()

        let status = InstanceCommandStatus(
            id: 1, name: "SeriesSearch", commandName: nil, message: nil,
            status: "queued", result: nil,
            queued: Date(), started: nil, ended: nil, trigger: "manual",
            instanceId: instanceId, subject: "Breaking Bad"
        )
        commands.track(status)

        #expect(commands.items[instanceId]?.count == 1)
        #expect(commands.items[instanceId]?.first?.subject == "Breaking Bad")
    }

    @Test @MainActor func mergeReplacesByIdAndKeepsSubject() async {
        let commands = Commands.makeForTesting()
        let instanceId = UUID()

        let queued = InstanceCommandStatus(
            id: 9, name: "MoviesSearch", commandName: nil, message: nil,
            status: "queued", result: nil,
            queued: Date(), started: nil, ended: nil, trigger: "manual",
            instanceId: instanceId, subject: "Inception"
        )
        commands.track(queued)

        var completed = queued
        completed.status = "completed"
        completed.ended = Date()
        completed.subject = nil // server won't know the subject
        commands.merge([completed], for: instanceId)

        let stored = commands.items[instanceId]?.first
        #expect(stored?.state == .completed)
        #expect(stored?.subject == "Inception") // preserved from local track
    }

    @Test @MainActor func defaultFilterKeepsOnlySearchCommands() async {
        let commands = Commands.makeForTesting()
        let instanceId = UUID()

        let search = InstanceCommandStatus(
            id: 1, name: "SeriesSearch", commandName: nil, message: nil,
            status: "queued", result: nil,
            queued: Date(), started: nil, ended: nil, trigger: "manual",
            instanceId: instanceId, subject: nil
        )
        let rss = InstanceCommandStatus(
            id: 2, name: "RssSync", commandName: nil, message: nil,
            status: "queued", result: nil,
            queued: Date(), started: nil, ended: nil, trigger: "scheduled",
            instanceId: instanceId, subject: nil
        )

        commands.merge([search, rss], for: instanceId)

        #expect(commands.filteredItems(showAll: false).count == 1)
        #expect(commands.filteredItems(showAll: true).count == 2)
    }
}
