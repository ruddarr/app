import os
import SwiftUI
import Sentry

@MainActor
@Observable
class SeriesReleases {
    var instance: Instance

    var items: [SeriesRelease] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool = false

    var indexers: [String] = []
    var qualities: [String] = []
    var protocols: [String] = []
    var languages: [String] = []
    var customFormats: [String] = []
    var releaseGroups: [String] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(_ series: Series, _ season: Season.ID?, _ episode: Episode.ID?) async {
        items = []
        error = nil
        isSearching = true
        setFilterData()

        do {
            items = try await dependencies.api.lookupSeriesReleases(series.id, season, episode, instance)
            setFilterData()
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.releases", message: "Series releases lookup failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isSearching = false
    }

    func setFilterData() {
        setIndexers()
        setQualities()
        setProtocols()
        setLanguages()
        setCustomFormats()
        setReleaseGroups()
    }

    func setIndexers() {
        var seen: Set<String> = []

        indexers = items
            .map { $0.indexerLabel }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    func setQualities() {
        var seen: Set<String> = []

        qualities = items
            .sorted { $0.quality.quality.resolution > $1.quality.quality.resolution }
            .map(\.quality.quality.normalizedName)
            .filter { seen.insert($0).inserted }
    }

    func setProtocols() {
        var seen: Set<String> = []

        protocols = items
            .map(\.network.label)
            .filter { seen.insert($0).inserted }
    }

    func setLanguages() {
        var seen: Set<String> = []

        languages = items
            .map { $0.languages?.map(\.label) ?? [] }
            .flatMap { $0 }
            .filter { seen.insert($0).inserted }
    }

    func setReleaseGroups() {
        var seen: Set<String> = []

        releaseGroups = items
            .compactMap { $0.releaseGroupLabel }
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func setCustomFormats() {
        let customFormatNames = items
            .compactMap(\.customFormats)
            .flatMap { $0 }
            .map { $0.label }

        customFormats = Array(Set(customFormatNames))
    }
}
