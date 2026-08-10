import os
import Foundation

/// How far a request got before it stopped, read back from `URLSessionTaskMetrics`. A failure that
/// knows its phase explains itself: a timeout in `.connecting` never reached the server at all,
/// while a timeout in `.waiting` means the socket opened and the server simply took longer than
/// the budget to answer. Those two look identical in `URLError` alone.
enum RequestPhase: String, Sendable {
    case resolving
    case connecting
    case sending
    case waiting
    case receiving
    case finished

    var label: String {
        switch self {
        case .resolving: "resolving host"
        case .connecting: "connecting"
        case .sending: "sending request"
        case .waiting: "waiting for response"
        case .receiving: "receiving response"
        case .finished: "finished"
        }
    }
}

extension RequestPhase {
    /// The stage still open when the transaction stopped. `URLSessionTaskTransactionMetrics` stamps
    /// each date as its stage completes, so the earliest stage with no end date is where it died.
    /// A reused connection reports no lookup or connect dates, hence the `isReusedConnection` guard.
    ///
    /// Kept separate from the `URLSessionTaskTransactionMetrics` initializer below because that type
    /// has no public initializer and so cannot be built in tests.
    static func stalled(
        isReusedConnection: Bool = false,
        domainLookupStart: Date? = nil,
        domainLookupEnd: Date? = nil,
        connectEnd: Date? = nil,
        requestEnd: Date? = nil,
        responseStart: Date? = nil,
        responseEnd: Date? = nil
    ) -> RequestPhase {
        if domainLookupStart != nil, domainLookupEnd == nil { return .resolving }
        if !isReusedConnection, connectEnd == nil { return .connecting }
        if requestEnd == nil { return .sending }
        if responseStart == nil { return .waiting }
        if responseEnd == nil { return .receiving }

        return .finished
    }

    init(_ metrics: URLSessionTaskTransactionMetrics) {
        self = Self.stalled(
            isReusedConnection: metrics.isReusedConnection,
            domainLookupStart: metrics.domainLookupStartDate,
            domainLookupEnd: metrics.domainLookupEndDate,
            connectEnd: metrics.connectEndDate,
            requestEnd: metrics.requestEndDate,
            responseStart: metrics.responseStartDate,
            responseEnd: metrics.responseEndDate
        )
    }
}

/// What the transport measured on the attempt that failed: the budget it was given, the wall time
/// it used, the stage it never got past, and whether it went over cellular. Enough for a timeout in
/// a diagnostics report to carry its own explanation — `elapsed` sitting at `budget` is a ceiling
/// that was too tight, `elapsed` well under it is a connection that was refused rather than slow.
struct TransportTrace: Equatable, Sendable {
    var budget: TimeInterval?
    var elapsed: TimeInterval?
    var phase: RequestPhase?
    var cellular: Bool?

    /// One line for the diagnostics screen and export, e.g. `waiting for response • 2.51s of 2.50s`.
    var summary: String? {
        var parts: [String] = []

        if let phase { parts.append(phase.label) }

        switch (elapsed, budget) {
        case (let elapsed?, let budget?): parts.append("\(Self.seconds(elapsed)) of \(Self.seconds(budget))")
        case (let elapsed?, nil): parts.append(Self.seconds(elapsed))
        case (nil, let budget?): parts.append("budget \(Self.seconds(budget))")
        case (nil, nil): break
        }

        if cellular == true { parts.append("over cellular") }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private static func seconds(_ value: TimeInterval) -> String {
        value < 10 ? String(format: "%.2fs", value) : String(format: "%.0fs", value)
    }
}

/// A per-request `URLSessionTaskDelegate` that keeps the few facts worth keeping from
/// `URLSessionTaskMetrics`. The metrics object is not `Sendable` and is only valid inside the
/// callback, so the values are extracted there and only plain ones escape.
final class RequestMetricsCollector: NSObject, URLSessionTaskDelegate, Sendable {
    private let captured = OSAllocatedUnfairLock(initialState: TransportTrace())

    /// The measurements for this attempt, stamped with the budget the caller gave it.
    func trace(budget: TimeInterval) -> TransportTrace {
        captured.withLock {
            var trace = $0
            trace.budget = budget
            return trace
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let elapsed = metrics.taskInterval.duration
        let transaction = metrics.transactionMetrics.last
        let phase = transaction.map { RequestPhase($0) }
        let cellular = transaction?.isCellular

        captured.withLock {
            $0.elapsed = elapsed
            $0.phase = phase
            $0.cellular = cellular
        }
    }
}
