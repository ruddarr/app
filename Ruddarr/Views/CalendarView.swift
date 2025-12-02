import SwiftUI

struct CalendarView: View {
    @State var calendar = MediaCalendar()

    @State private var scrollView: ScrollViewProxy?
    @State private var initializationError: API.Error?
    @State private var hideCalendarView: Bool = true

    @AppStorage("calendarMonitored", store: dependencies.store) private var onlyMonitored: Bool = false
    @AppStorage("calendarSpecials", store: dependencies.store) private var hideSpecials: Bool = false

    @State private var onlyPremieres: Bool = false
    @State private var displayedInstance: String = ".all"
    @State private var displayedMediaType: CalendarMediaType = .all

    @EnvironmentObject var settings: AppSettings

    private let firstWeekday = Calendar.current.firstWeekday

    private var gridLayout = [
        GridItem(.fixed(50), alignment: .center),
        GridItem(.flexible())
    ]

    var body: some View {
        // swiftlint:disable:next closure_body_length
        NavigationStack(path: dependencies.$router.calendarPath) {
            Group {
                if settings.configuredInstances.isEmpty {
                    NoInstance()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: gridLayout, alignment: .leading, spacing: 0) {
                                ForEach(calendar.dates, id: \.self) { timestamp in
                                    let date = Date(timeIntervalSince1970: timestamp)
                                    let weekday = Calendar.current.component(.weekday, from: date)

                                    if firstWeekday == weekday {
                                        CalendarWeekRange(date: date)
                                    }

                                    CalendarDate(date: date).offset(x: -6)
                                    media(for: timestamp, date: date)
                                }
                            }

                            Group {
                                if calendar.isLoadingFuture {
                                    ProgressView().tint(.secondary)
                                } else if !calendar.dates.isEmpty {
                                    Button("Load More") {
                                        calendar.loadMoreDates()
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.buttonTint)
                                }
                            }.padding(.bottom, 32)
                        }
                        .opacity(hideCalendarView ? 0 : 1)
                        .onAppear {
                            scrollView = proxy
                        }
                        .onBecomeActive {
                            await load()
                        }
                    }
                }
            }
            .viewPadding(.horizontal)
            .scrollIndicators(.never)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                filtersMenu
                todayButton
            }
            .onAppear {
                if Set(calendar.instances.map(\.id)) != Set(settings.instances.map(\.id)) {
                    calendar.reset()
                    calendar.instances = settings.instances
                    hideCalendarView = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                withAnimation(.smooth) {
                    scrollTo(calendar.today())
                }
            }
            .task {
                await load()
            }
            .alert(
                isPresented: calendar.errorBinding,
                error: calendar.error
            ) { _ in
                Button("OK") { calendar.error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }.tint(nil)
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if calendar.isLoading && calendar.dates.isEmpty {
                    Loading()
                } else if initialLoadingFailed {
                    contentUnavailable
                }
            }
        }
    }

    var notConnectedToInternet: Bool {
        if !calendar.dates.isEmpty { return false }
        if case .notConnectedToInternet = calendar.error { return true }
        return false
    }

    var initialLoadingFailed: Bool {
        if initializationError == nil { return false }
        return calendar.dates.isEmpty && (calendar.movies.isEmpty || calendar.episodes.isEmpty)
    }

    var displayMovies: Bool {
        [.all, .movies].contains(displayedMediaType)
    }

    var displaySeries: Bool {
        [.all, .series].contains(displayedMediaType)
    }

    var filteredMovies: [TimeInterval: [Movie]] {
        var movies = calendar.movies

        if displayedInstance != ".all" {
            movies = movies.mapValues { items in
                items.filter { $0.instanceId?.isEqual(to: displayedInstance) == true }
            }
        }

        if onlyMonitored {
            movies = movies.mapValues { items in
                items.filter { $0.monitored }
            }
        }

        return movies
    }

    var filteredEpisodes: [TimeInterval: [Episode]] {
        var episodes = calendar.episodes

        episodes = episodes.mapValues { items in
            let grouped = Dictionary(grouping: items, by: \.calendarGroup)

            return grouped.values.compactMap { group in
                guard var dummy = group.first else { return group[0] }
                dummy.calendarGroupCount = group.count
                return dummy
            }.sorted {
                ($0.airDateUtc ?? Date.distantPast, $0.episodeNumber) <
                ($1.airDateUtc ?? Date.distantPast, $1.episodeNumber)
            }
        }

        if displayedInstance != ".all" {
            episodes = episodes.mapValues { items in
                items.filter { $0.instanceId?.isEqual(to: displayedInstance) == true }
            }
        }

        if onlyMonitored {
            episodes = episodes.mapValues { items in
                items.filter { $0.monitored }
            }
        }

        if onlyPremieres {
            episodes = episodes.mapValues { items in
                items.filter { $0.isPremiere }
            }
        }

        if hideSpecials {
            episodes = episodes.mapValues { items in
                items.filter { !$0.isSpecial }
            }
        }

        return episodes
    }

    func load(force: Bool = false) async {
        if calendar.isLoading {
            return
        }

        let lastFetch = Occurrence.since("calendarFetch")
        let firstLoad = calendar.dates.isEmpty

        if !force && !calendar.dates.isEmpty && lastFetch < 10 {
            initializationError = nil
            return
        }

        if force {
            initializationError = nil
        }

        await calendar.load()

        if calendar.dates.isEmpty {
            initializationError = calendar.error
        }

        Occurrence.occurred("calendarFetch")

        guard firstLoad else { return }

        try? await Task.sleep(for: .milliseconds(15))
        scrollTo(calendar.today())
        try? await Task.sleep(for: .milliseconds(15))
        hideCalendarView = false
    }

    func scrollTo(_ timestamp: TimeInterval) {
        scrollView?.scrollTo(timestamp, anchor: .center)
    }

    func media(for timestamp: TimeInterval, date: Date) -> some View {
        VStack(spacing: 8) {
            if displayMovies, let movies = filteredMovies[timestamp] {
                ForEach(movies) { movie in
                    CalendarMovie(date: date, movie: movie)
                }
            }

            if displaySeries, let episodes = filteredEpisodes[timestamp] {
                ForEach(episodes) { episode in
                    CalendarEpisode(episode: episode)
                }
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    var todayButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Today", systemImage: "calendar.day.timeline.left") {
                Task { @MainActor in
                    withAnimation(.smooth) {
                        self.scrollTo(self.calendar.today())
                    }
                }
            }
            .tint(.primary)
        }
    }

    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("Connection Failure", systemImage: "exclamationmark.triangle")
        } description: {
            Text(initializationError?.recoverySuggestionFallback ?? "")
        } actions: {
            Button("Retry") {
                Task { await load(force: true) }
            }
        }
    }

    var filtersMenu: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                if calendar.instances.count > 1 {
                    instancePicker
                }

                Picker(selection: $displayedMediaType, label: Text("Media Type")) {
                    ForEach(CalendarMediaType.allCases, id: \.self) { type in
                        type.label
                    }
                }
                .pickerStyle(.inline)

                Toggle(isOn: $onlyMonitored) {
                    Label("Monitored", systemImage: "bookmark")
                        .symbolVariant(onlyMonitored ? .fill : .none)
                }

                Toggle(isOn: $onlyPremieres) {
                    Label("Premieres", systemImage: "play")
                        .symbolVariant(onlyPremieres ? .fill : .none)
                }

                Section {
                    Toggle(isOn: $hideSpecials) {
                        Label("Hide Specials", systemImage: "star")
                            .symbolVariant(hideSpecials ? .slash.fill : .slash)
                    }
                }
            } label: {
                if displayedMediaType != .all || onlyPremieres || onlyMonitored || hideSpecials {
                    Image("filters.badge")
                        .offset(y: 3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.tint, .primary)
                } else {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
            .menuIndicator(.hidden)
        }
    }

    var instancePicker: some View {
        Menu {
            Picker("Instance", selection: $displayedInstance) {
                Text("Any Instance").tag(".all")

                ForEach(calendar.instances) { instance in
                    Text(instance.label).tag(instance.id.uuidString)
                }
            }
            .pickerStyle(.inline)
        } label: {
            let label = calendar.instances.first {
                $0.id.uuidString == displayedInstance
            }?.label ?? String(localized: "Instance")

            Label(label, systemImage: "internaldrive")
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}

#Preview("Offline") {
    dependencies.api.movieCalendar = { _, _, _ in
        throw API.Error.notConnectedToInternet
    }

    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}

#Preview("Failure") {
    dependencies.api.movieCalendar = { _, _, _ in
        throw API.Error.urlError(
            URLError(.badServerResponse)
        )
    }

    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}
