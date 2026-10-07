import Foundation
import AppIntents

struct UpcomingReleasesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Upcoming Releases"
    static let description: IntentDescription? = IntentDescription("Lists the movies and episodes releasing in the coming days.")

    @Parameter(title: "Days", default: 7)
    var days: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get releases for the next \(\.$days) days")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        let span = min(max(days, 1), 90)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: span, to: start) ?? start
        let instances = await MainActor.run { AppSettings.shared.configuredInstances }

        let results = await withTaskGroup(of: [UpcomingRelease]?.self, returning: [[UpcomingRelease]?].self) { group in
            for instance in instances {
                group.addTask {
                    try? await upcomingReleases(instance, start..<end)
                }
            }

            var results: [[UpcomingRelease]?] = []

            for await result in group {
                results.append(result)
            }

            return results
        }

        if !results.isEmpty, results.allSatisfy({ $0 == nil }) {
            throw AppError(String(localized: "Failed to load the calendar."))
        }

        let lines = results
            .compactMap { $0 }
            .joined()
            .sorted { $0.date < $1.date }
            .map(\.text)

        let summary = lines.isEmpty
            ? String(localized: "Nothing is releasing in the next \(span) days.")
            : lines.prefix(10).joined(separator: "\n")

        return .result(value: lines, dialog: "\(summary)")
    }
}

private struct UpcomingRelease: Sendable {
    let date: Date
    let text: String
}

private func upcomingReleases(_ instance: Instance, _ range: Range<Date>) async throws -> [UpcomingRelease] {
    switch instance.type {
    case .radarr:
        try await dependencies.api.radarr.calendar(range.lowerBound, range.upperBound, instance)
            .flatMap { movieReleases($0, range) }
    case .sonarr:
        try await dependencies.api.sonarr.calendar(range.lowerBound, range.upperBound, instance)
            .compactMap { episodeRelease($0, range) }
    }
}

private func movieReleases(_ movie: Movie, _ range: Range<Date>) -> [UpcomingRelease] {
    let releases: [(date: Date?, type: String)] = [
        (movie.inCinemas, String(localized: "In Cinemas")),
        (movie.digitalRelease, String(localized: "Digital Release")),
        (movie.physicalRelease, String(localized: "Physical Release")),
    ]

    return releases.compactMap { release in
        guard let date = release.date, range.contains(date) else { return nil }

        let day = date.formatted(.dateTime.weekday().month().day())

        return UpcomingRelease(date: date, text: "\(day) · \(movie.title) (\(release.type))")
    }
}

private func episodeRelease(_ episode: Episode, _ range: Range<Date>) -> UpcomingRelease? {
    guard let date = episode.airDateUtc, range.contains(date) else { return nil }

    let time = date.formatted(.dateTime.weekday().month().day().hour().minute())
    let parts = [episode.series?.title, episode.episodeLabel, episode.title].compactMap { $0 }

    return UpcomingRelease(date: date, text: "\(time) · \(parts.joined(separator: " · "))")
}
