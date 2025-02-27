import SwiftUI

struct CalendarView: View {
    @State var calendar = MediaCalendar()

    @State private var scrollView: ScrollViewProxy?
    @State private var initializationError: API.Error?

    @AppStorage("calendarMonitored", store: dependencies.store) private var onlyMonitored: Bool = false

    @State private var onlyPremieres: Bool = false
    @State private var displayedInstance: String = ".all"
    @State private var displayedMediaType: CalendarMediaType = .all

    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    private let firstWeekday = Calendar.current.firstWeekday

    private var gridLayout = [
        GridItem(.fixed(50), alignment: .center),
        GridItem(.flexible())
    ]

    var body: some View {
        // swiftlint:disable closure_body_length
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
                                }
                            }.padding(.bottom, 32)
                        }
                        .onChange(of: scenePhase, handleScenePhaseChange)
                        .onAppear {
                            scrollView = proxy
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
                if calendar.instances != settings.instances {
                    calendar.reset()
                    calendar.instances = settings.instances
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
            }
            .overlay {
                if notConnectedToInternet {
                    NoInternet()
                } else if calendar.isLoading && calendar.dates.isEmpty {
                    Loading()
                } else if initializationError != nil {
                    contentUnavailable
                }
            }
        }
        // swiftlint:enable closure_body_length
    }

    var notConnectedToInternet: Bool {
        if !calendar.dates.isEmpty { return false }
        if case .notConnectedToInternet = calendar.error { return true }
        return false
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

        return episodes
    }

    func load(force: Bool = false) async {
        let lastFetch = Occurrence.since("calendarFetch")

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollTo(calendar.today())
        }
    }

    func handleScenePhaseChange(_ from: ScenePhase, _ to: ScenePhase) {
        if from == .background, to == .inactive {
            Task { await load() }
        }
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
            Button("Today") {
                withAnimation(.smooth) {
                    scrollTo(calendar.today())
                }
            }
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

                Toggle(isOn: $onlyPremieres) {
                    Label("Premieres", systemImage: "play")
                        .symbolVariant(onlyPremieres ? .fill : .none)
                }

                Toggle(isOn: $onlyMonitored) {
                    Label("Monitored", systemImage: "bookmark")
                        .symbolVariant(onlyMonitored ? .fill : .none)
                }
            } label: {
                if displayedMediaType != .all || onlyPremieres || onlyMonitored {
                    Image("filters.badge").offset(y: 3.2)
                } else {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
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
