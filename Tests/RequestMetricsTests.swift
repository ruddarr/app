import Foundation
import Testing

struct RequestPhaseTests {
    private static let start = Date(timeIntervalSince1970: 1_700_000_000)
    private static func mark(_ offset: TimeInterval) -> Date { start.addingTimeInterval(offset) }

    // Name resolution began and never finished — the request never had an address to dial.
    @Test func stallsWhileResolving() {
        let phase = RequestPhase.stalled(domainLookupStart: Self.mark(0))

        #expect(phase == .resolving)
    }

    // The address resolved but no handshake ever completed: the host never answered. This is what a
    // filtered, blocked or absent server looks like — as opposed to a slow one.
    @Test func stallsWhileConnecting() {
        let phase = RequestPhase.stalled(
            domainLookupStart: Self.mark(0),
            domainLookupEnd: Self.mark(0.01)
        )

        #expect(phase == .connecting)
    }

    // A reused connection reports no lookup or connect dates at all, so the connect check has to be
    // skipped rather than read as a failed handshake.
    @Test func reusedConnectionIsNotMistakenForAFailedHandshake() {
        let phase = RequestPhase.stalled(
            isReusedConnection: true,
            requestEnd: Self.mark(0.02)
        )

        #expect(phase == .waiting)
    }

    // The socket opened and the request went out, but no response headers came back — the instance
    // is alive and simply slower than the budget allowed.
    @Test func stallsWhileWaitingForResponse() {
        let phase = RequestPhase.stalled(
            connectEnd: Self.mark(0.01),
            requestEnd: Self.mark(0.02)
        )

        #expect(phase == .waiting)
    }

    // Connected, but the request body never finished going out.
    @Test func stallsWhileSending() {
        let phase = RequestPhase.stalled(connectEnd: Self.mark(0.01))

        #expect(phase == .sending)
    }

    // Headers arrived, the body did not finish — a stalled or truncated response.
    @Test func stallsWhileReceiving() {
        let phase = RequestPhase.stalled(
            connectEnd: Self.mark(0.01),
            requestEnd: Self.mark(0.02),
            responseStart: Self.mark(0.03)
        )

        #expect(phase == .receiving)
    }

    @Test func completedTransactionReportsFinished() {
        let phase = RequestPhase.stalled(
            connectEnd: Self.mark(0.01),
            requestEnd: Self.mark(0.02),
            responseStart: Self.mark(0.03),
            responseEnd: Self.mark(0.04)
        )

        #expect(phase == .finished)
    }
}

struct TransportTraceTests {
    // The comparison the whole trace exists for: time spent against time allowed. Elapsed sitting at
    // the budget is a ceiling that was too tight.
    @Test func summaryPairsElapsedWithBudget() {
        let trace = TransportTrace(budget: 2.5, elapsed: 2.51, phase: .waiting)
        #expect(trace.summary == "waiting for response • 2.51s of 2.50s")
    }

    // Budgets of ten seconds and up (`.slow`, `.releaseSearch`) drop the decimals.
    @Test func summaryDropsDecimalsOnLongBudgets() {
        let trace = TransportTrace(budget: 90, elapsed: 90.4, phase: .waiting)
        #expect(trace.summary == "waiting for response • 90s of 90s")
    }

    // Wi-Fi Assist is not readable as a setting, but the interface a request actually used is.
    @Test func summaryFlagsCellular() {
        let trace = TransportTrace(budget: 10, elapsed: 3, phase: .connecting, cellular: true)
        #expect(trace.summary == "connecting • 3.00s of 10s • over cellular")
    }

    // Wi-Fi is the expected case and says nothing worth a line of its own.
    @Test func summaryStaysQuietOnWiFi() {
        let trace = TransportTrace(budget: 10, elapsed: 3, phase: .connecting, cellular: false)
        #expect(trace.summary == "connecting • 3.00s of 10s")
    }

    // Nothing measured: the failure landed before the transport produced any metrics.
    @Test func emptyTraceHasNoSummary() {
        #expect(TransportTrace().summary == nil)
    }
}
