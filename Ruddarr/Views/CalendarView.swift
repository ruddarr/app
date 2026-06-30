import SwiftUI

struct CalendarView: View {
    @State var calendar = MediaCalendar()

    @State private var scrollView: ScrollViewProxy?
    @State private var initializationError: API.Error?
    @State private var alertPresented = false
    @State private var hideCalendarView: Bool = true
    @State var isRetrying: Bool = false
    @State private var selectedMedia: CalendarSelection?
    @State private var queue = Queue.shared

    @AppStorage("calendarMonitored", store: dependencies.store) var onlyMonitored: Bool = false
    @AppStorage("calendarSpecials", store: dependencies.store) var hideSpecials: Bool = false

    @State var onlyPremieres: Bool = false
    @State var displayedInstance: String = .all
    @State var displayedMediaType: CalendarMediaType = .all

    @Environment(AppSettings.self) private var settings
    @Environment(\.deviceType) private var deviceType

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
                    calendarScrollView
                }
            }
            .scenePadding(.horizontal)
            .scrollIndicators(.never)
            .safeNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                filtersMenu

                errorIndicator
                todayButton
            }
            .onAppear(perform: syncInstances)
            .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                withAnimation(.smooth) {
                    scrollTo(calendar.today())
                }
            }
            .task {
                await load()
            }
            .alert(
                isPresented: $alertPresented,
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
            #if os(iOS)
                .sheet(item: $selectedMedia) { selection in
                    CalendarDetailSheet(selection: selection)
                        .presentationDetents(dynamic: deviceType == .pad ? [.large] : [.fraction(0.8), .large])
                        .presentationSizing(.page)
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.sheetBackground)
                }
            #endif
        }
    }

    var calendarScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                calendarGrid

                Group {
                    if calendar.isLoadingFuture {
                        ProgressView().tint(.secondary)
                    } else if !calendar.dates.isEmpty {
                        Button {
                            calendar.loadMoreDates()
                        } label: {
                            ButtonLabel(text: "Load More", size: .small)
                        }
                        .actionButton()
                        .fixedSize()
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

    var calendarGrid: some View {
        let moviesByDate = displayMovies ? filteredMovies : [:]
        let episodesByDate = displaySeries ? filteredEpisodes : [:]
        let active = displayMovies ? queue.active : []

        return LazyVGrid(columns: gridLayout, alignment: .leading, spacing: 0) {
            ForEach(calendar.dates, id: \.self) { timestamp in
                let date = Date(timeIntervalSince1970: timestamp)
                let weekday = Calendar.current.component(.weekday, from: date)

                if firstWeekday == weekday {
                    CalendarWeekRange(date: date)
                }

                CalendarDate(date: date).offset(x: -6)

                media(
                    date: date,
                    movies: moviesByDate[timestamp],
                    episodes: episodesByDate[timestamp],
                    active: active
                )
            }
        }
    }

    func syncInstances() {
        guard Set(calendar.instances.map(\.id)) != Set(settings.instances.map(\.id)) else {
            return
        }

        calendar.reset()
        calendar.instances = settings.instances
        hideCalendarView = true
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
        calendar.movies.mapValues { items in
            let filtered = items.filter { movie in
                if displayedInstance != .all, movie.instanceId?.isEqual(to: displayedInstance) != true { return false }
                if onlyMonitored, !movie.monitored { return false }
                return true
            }

            guard filtered.count > 1 else { return filtered }
            return filtered.sorted(by: areMoviesInCalendarOrder)
        }
    }

    var filteredEpisodes: [TimeInterval: [Episode]] {
        let active = queue.active

        return calendar.episodes.mapValues { items in
            let filtered = items.filter(includeEpisodeInCalendar)
            let grouped = Dictionary(grouping: filtered, by: \.calendarGroup)
            let episodes = grouped.values.compactMap { group -> Episode? in
                guard var episode = group.first else { return nil }
                episode.calendarGroupCount = group.count
                episode.queueStatusInCalendar = group
                    .compactMap { queueStatus(\.episodeId, $0.id, $0.instanceId, in: active) }
                    .max()
                return episode
            }

            guard episodes.count > 1 else { return episodes }
            return episodes.sorted(by: areEpisodesInCalendarOrder)
        }
    }

    func queueStatus(_ idKey: KeyPath<QueueItem, Int?>, _ id: Int, _ instanceId: Instance.ID?, in items: [QueueItem]) -> QueueItemStatus? {
        guard let instanceId else { return nil }
        return items.highestStatus { $0[keyPath: idKey] == id && $0.instanceId == instanceId }
    }

    func includeEpisodeInCalendar(_ episode: Episode) -> Bool {
        if displayedInstance != .all, episode.instanceId?.isEqual(to: displayedInstance) != true { return false }
        if onlyMonitored, !episode.isMonitoredInCalendar { return false }
        if onlyPremieres, !episode.isPremiere { return false }
        if hideSpecials, episode.isSpecial { return false }
        return true
    }

    func areMoviesInCalendarOrder(_ lhs: Movie, _ rhs: Movie) -> Bool {
        if lhs.monitored != rhs.monitored {
            return lhs.monitored
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    func areEpisodesInCalendarOrder(_ lhs: Episode, _ rhs: Episode) -> Bool {
        let lhsDate = lhs.airDateUtc ?? .distantPast
        let rhsDate = rhs.airDateUtc ?? .distantPast

        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        if lhs.isMonitoredInCalendar != rhs.isMonitoredInCalendar {
            return lhs.isMonitoredInCalendar
        }

        return lhs.episodeNumber < rhs.episodeNumber
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

        if force && calendar.error != nil {
            alertPresented = true
        } else if let error = calendar.errors.first {
            dependencies.toast.show(.error(error.recoverySuggestionFallback))
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

    func media(date: Date, movies: [Movie]?, episodes: [Episode]?, active: [QueueItem]) -> some View {
        VStack(spacing: 8) {
            if let movies {
                ForEach(movies) { movie in
                    CalendarMovie(
                        date: date,
                        movie: movie,
                        status: queueStatus(\.movieId, movie.id, movie.instanceId, in: active),
                        open: open
                    )
                }
            }

            if let episodes {
                ForEach(episodes) { episode in
                    CalendarEpisode(
                        episode: episode,
                        status: episode.queueStatusInCalendar,
                        open: open
                    )
                }
            }

            Spacer()
        }
        .padding(.top, 4)
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

    func open(_ selection: CalendarSelection) {
        #if os(iOS)
            selectedMedia = selection
        #else
            selection.jumpToTab()
        #endif
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

#Preview("Partial Failure") {
    dependencies.api.episodeCalendar = { _, _, _ in
        throw API.Error.urlError(
            URLError(.badServerResponse)
        )
    }

    dependencies.router.selectedTab = .calendar

    return ContentView()
        .withAppState()
}
