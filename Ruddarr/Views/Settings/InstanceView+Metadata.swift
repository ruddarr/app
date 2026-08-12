import SwiftUI

extension InstanceView {
    var summaryParts: [String] {
        var parts: [String] = []

        if case .loaded(let stats) = libraryState {
            if instance.type == .radarr {
                parts.append(String(localized: "\(stats.movies) Movie"))
            }

            if instance.type == .sonarr {
                parts.append(String(localized: "\(stats.series) Series"))

                if stats.episodes > 0 {
                    parts.append(String(localized: "\(stats.episodes) Episode"))
                }
            }

            if stats.size > 0 {
                parts.append(formatBytes(stats.size))
            }
        }

        if let version = version ?? instance.version {
            parts.append("v\(version)")
        }

        return parts
    }

    @ViewBuilder
    var metadataFooter: some View {
        ZStack(alignment: .leading) {
            if metadataReady {
                Text(verbatim: summaryParts.joined(separator: " • "))
                    .contentTransition(.numericText())
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }
        }
        .animation(.snappy, value: metadataReady)
        .animation(.snappy, value: summaryParts)
    }

    func loadSummary() async {
        async let library: Void = loadLibraryIfNeeded()
        async let diskSpace: Void = loadDiskSpaceIfNeeded()

        _ = await (library, diskSpace)
    }

    func loadLibraryIfNeeded() async {
        if libraryRefreshing { return }
        await loadLibrary()
    }

    private var cachedStats: InstanceStats? {
        get async {
            switch instance.type {
            case .radarr where radarrInstance.id == instance.id && !radarrInstance.movies.items.isEmpty:
                await InstanceStats.make(movies: radarrInstance.movies.items)
            case .sonarr where sonarrInstance.id == instance.id && !sonarrInstance.series.items.isEmpty:
                await InstanceStats.make(series: sonarrInstance.series.items)
            default:
                instance.stats
            }
        }
    }

    private func fetchStats() async throws -> InstanceStats {
        switch instance.type {
        case .radarr: await InstanceStats.make(movies: try await dependencies.api.fetchMovies(instance))
        case .sonarr: await InstanceStats.make(series: try await dependencies.api.fetchSeries(instance))
        }
    }

    func loadLibrary() async {
        libraryRefreshing = true
        defer { libraryRefreshing = false }

        if !libraryState.isLoaded {
            libraryState = if let stats = await cachedStats { .loaded(stats) } else { .loading }
        }

        do {
            async let statusTask = dependencies.api.systemStatus(instance)

            let stats = try await fetchStats()

            if let status = try? await statusTask {
                version = status.version
            }

            libraryState = .loaded(stats)

            var updated = instance
            updated.stats = stats
            updated.version = version
            settings.saveInstanceMetadata(updated)
        } catch is CancellationError {
                //
        } catch {
            if !libraryState.isLoaded {
                libraryState = .failed
            }
        }
    }

    var metadataReady: Bool {
        switch libraryState {
        case .loaded, .failed: true
        case .idle, .loading: false
        }
    }

    enum MetadataState<Value> {
        case idle
        case loading
        case loaded(Value)
        case failed

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }

        var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
    }
}

extension InstanceView {
    func loadDiskSpace() async {
        diskSpaceState = .loading

        do {
            diskSpaceState = .loaded(try await dependencies.api.fetchDiskSpace(instance))
        } catch is CancellationError {
                //
        } catch {
            diskSpaceState = .failed
        }
    }

    func loadDiskSpaceIfNeeded() async {
        if case .loaded = diskSpaceState { return }
        if diskSpaceState.isLoading { return }
        await loadDiskSpace()
    }

    var diskSpaceUnavailable: Bool {
        switch diskSpaceState {
        case .loaded(let locations): locations.isEmpty
        case .failed: true
        case .idle, .loading: false
        }
    }

#if os(macOS)
    var diskSpaceSection: some View {
        Section {
            switch diskSpaceState {
            case .loaded(let locations):
                diskSpaceRows(locations)
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failed:
                EmptyView()
            }
        } header: {
            Text("Disk Space")
        } footer: {
            diskSpaceFooter
        }
    }
#else
    var diskSpaceSection: some View {
        Section {
            if diskSpaceExpanded, case .loaded(let locations) = diskSpaceState {
                diskSpaceRows(locations)
            }
        } header: {
            diskSpaceHeader
        } footer: {
            if diskSpaceExpanded {
                diskSpaceFooter
            }
        }
        .listSectionSpacing(diskSpaceExpanded ? .default : .compact)
    }

    var diskSpaceHeader: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Disk Space")

                if diskSpaceState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .rotationEffect(.degrees(diskSpaceExpanded ? 90 : 0))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { diskSpaceExpanded.toggle() }

            if diskSpaceExpanded {
                Task { await loadDiskSpaceIfNeeded() }
            }
        }
    }
#endif

    func diskSpaceRows(_ locations: [InstanceDiskSpace]) -> some View {
        ForEach(locations) { location in
            LabeledContent {
                Text(verbatim: "%@ / %@".placeholders(
                    formatBytes(location.freeSpace),
                    formatBytes(location.totalSpace)
                ))
                .foregroundStyle(.secondary)
                .font(.subheadline)
            } label: {
                Text(location.displayLabel)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    var diskSpaceFooter: some View {
        Text("Displayed storage reflects the available and total disk space.")
    }
}

#Preview {
    let settings = AppSettings()

    dependencies.router.selectedTab = .settings

    if let instance = settings.instances.first {
        dependencies.router.settingsPath.append(
            SettingsView.Path.viewInstance(instance.id)
        )
    }

    return ContentView()
        .withAppState()
}

#Preview("Sonarr") {
    let settings = AppSettings()

    dependencies.router.selectedTab = .settings

    if let instance = settings.instances.first(where: { $0.type == .sonarr }) {
        dependencies.router.settingsPath.append(
            SettingsView.Path.viewInstance(instance.id)
        )
    }

    return ContentView()
        .withAppState()
}
