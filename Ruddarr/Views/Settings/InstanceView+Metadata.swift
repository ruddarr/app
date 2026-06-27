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

            parts.append(formatBytes(stats.size, adaptive: true))
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

    var diskSpaceUnavailable: Bool {
        switch diskSpaceState {
        case .loaded(let locations): return locations.isEmpty
        case .failed: return true
        case .idle, .loading: return false
        }
    }

    @ViewBuilder
    var diskSpaceSection: some View {
        Section {
            if diskSpaceExpanded {
                switch diskSpaceState {
                case .loaded(let locations):
                    ForEach(locations) { location in
                        LabeledContent {
                            Text(verbatim: String(
                                format: "%@ / %@",
                                formatBytes(Int(clamping: location.freeSpace), adaptive: true),
                                formatBytes(Int(clamping: location.totalSpace), adaptive: true)
                            ))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        } label: {
                            Text(location.displayLabel)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                case .idle, .loading, .failed:
                    EmptyView()
                }
            }
        } header: {
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
        #if os(iOS)
            .listSectionSpacing(diskSpaceExpanded ? .default : .compact)
        #endif
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
            libraryState = .loaded(await InstanceStats.make(movies: radarrInstance.movies.items))
            return
        }

        if instance.type == .sonarr, sonarrInstance.id == instance.id, !sonarrInstance.series.items.isEmpty {
            libraryState = .loaded(await InstanceStats.make(series: sonarrInstance.series.items))
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
