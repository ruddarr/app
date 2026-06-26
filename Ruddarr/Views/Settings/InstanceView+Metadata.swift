import SwiftUI

enum MetadataState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension InstanceView {
    var summaryParts: [String] {
        var parts: [String] = []

        if case .loaded(let stats) = libraryState {
            if instance.type == .radarr {
                parts.append(String(localized: "\(stats.movies) Movie"))
            }

            if instance.type == .sonarr {
                parts.append(String(localized: "\(stats.series) Series"))
                parts.append(String(localized: "\(stats.episodes) Episode"))
            }

            parts.append(formatBytes(stats.size))
        }

        if let version = instance.version {
            parts.append(version)
        }

        return parts
    }

    @ViewBuilder
    var metadataFooter: some View {
        HStack(spacing: 6) {
            Text(verbatim: summaryParts.joined(separator: " • "))
                .contentTransition(.numericText())

            if libraryState.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: summaryParts)
    }

    @ViewBuilder
    var diskSpaceSection: some View {
        Section {
            if diskSpaceExpanded {
                switch diskSpaceState {
                case .loaded(let locations):
                    if locations.isEmpty {
                        Text("No locations found").foregroundStyle(.secondary)
                    } else {
                        ForEach(locations) { location in
                            LabeledContent {
                                Text(verbatim: "\(formatBytes(Int(location.freeSpace))) / \(formatBytes(Int(location.totalSpace)))")
                                    .foregroundStyle(.secondary)
                            } label: {
                                Text(location.displayLabel)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                case .failed:
                    retryRow { await loadDiskSpace() }
                case .idle, .loading:
                    EmptyView()
                }
            }
        } header: {
            HStack {
                loadingHeader(Text("Disk Space"), loading: diskSpaceState.isLoading)

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
    }

    func loadingHeader(_ title: Text, loading: Bool) -> some View {
        HStack(spacing: 4) {
            title

            if loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }
        }
    }

    @ViewBuilder
    func retryRow(_ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Text("Couldn't load data", comment: "Inline metadata load error")
                Spacer()
                Image(systemName: "arrow.clockwise")
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func loadSummary() async {
        async let library: Void = loadLibraryIfNeeded()
        async let diskSpace: Void = loadDiskSpaceIfNeeded()

        _ = await (library, diskSpace)
    }

    func loadLibraryIfNeeded() async {
        if case .loaded = libraryState { return }
        if libraryState.isLoading { return }
        await loadLibrary()
    }

    func loadDiskSpaceIfNeeded() async {
        if case .loaded = diskSpaceState { return }
        if diskSpaceState.isLoading { return }
        await loadDiskSpace()
    }

    func loadLibrary() async {
        if instance.type == .radarr, radarrInstance.id == instance.id, !radarrInstance.movies.items.isEmpty {
            libraryState = .loaded(InstanceStats(movies: radarrInstance.movies.items))
            return
        }

        if instance.type == .sonarr, sonarrInstance.id == instance.id, !sonarrInstance.series.items.isEmpty {
            libraryState = .loaded(InstanceStats(series: sonarrInstance.series.items))
            return
        }

        if let stats = instance.stats {
            libraryState = .loaded(stats)
            return
        }

        libraryState = .loading

        do {
            let stats: InstanceStats

            if instance.type == .radarr {
                stats = await InstanceStats.make(movies: try await dependencies.api.fetchMovies(instance))
            } else {
                stats = await InstanceStats.make(series: try await dependencies.api.fetchSeries(instance))
            }

            libraryState = .loaded(stats)

            var updated = instance
            updated.stats = stats
            settings.saveInstance(updated)
        } catch is CancellationError {
            //
        } catch {
            libraryState = .failed
        }
    }

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
