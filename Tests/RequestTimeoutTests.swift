import Testing

struct RequestTimeoutTests {
    // A symmetric budget (server-processing-bound classes: .slow, .releaseSearch, lookups) must
    // never differ by locality — this is what keeps a slow-but-alive LAN response from being cut off.
    @Test func symmetricBudgetIgnoresLocality() {
        let timeout = RequestTimeout(90)
        #expect(timeout.interval(isLocal: true) == 90)
        #expect(timeout.interval(isLocal: false) == 90)
    }

    // The reachability/candidate-confirming budget: fast on a LAN, full on a remote.
    @Test func asymmetricBudgetIsShortLocalFullRemote() {
        let timeout = RequestTimeout(local: 2.5, remote: 10)
        #expect(timeout.interval(isLocal: true) == 2.5)
        #expect(timeout.interval(isLocal: false) == 10)
    }

    @Test func defaultConfirmsLocalFastAndRemoteFull() {
        #expect(RequestTimeout.default.interval(isLocal: true) == 2.5)
        #expect(RequestTimeout.default.interval(isLocal: false) == 10)
    }
}
