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
}
