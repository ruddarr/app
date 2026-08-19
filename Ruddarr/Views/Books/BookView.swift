import SwiftUI

struct BookView: View {
    @Binding var book: Book

    @State var series: [BookSeries] = []
    @State private var overview: String = ""

    @State var seriesExpanded: Bool = false
    @State private var descriptionTruncated = true
    @State private var togglingMonitor: Bool = false

    @Environment(AppSettings.self) var settings
    @Environment(ChaptarrInstance.self) var instance
    @Environment(\.deviceType) var deviceType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                details
                    .padding(.bottom)

                if !overview.isEmpty {
                    description(overview)
                        .padding(.bottom)
                }

                if deviceType == .phone, book.exists {
                    actions
                        .padding(.bottom)
                }

                if book.exists, let bookSeries {
                    seriesSection(bookSeries)
                        .padding(.bottom)
                }

                if book.exists {
                    information
                        .padding(.bottom)
                }
            }
            .padding(.top)
            .viewBottomPadding()
            .scenePadding(.horizontal)
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            CalendarSheetAwareToolbar()

            if book.exists {
                toolbarMonitorButton
            }

            if !book.webLinks.isEmpty {
                toolbarMenu
            }
        }
        .task(id: book.overview) {
            overview = book.overview?.htmlDecoded ?? ""
        }
        .task {
            async let details: Void = loadDetails()
            async let series: Void = loadSeries()

            _ = await (details, series)
        }
        .sensoryAlert(
            isPresented: instance.books.errorBinding,
            error: instance.books.error
        ) { _ in
            Button("OK") { instance.books.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: book.monitored, loading: togglingMonitor)
            }
            .allowsHitTesting(!togglingMonitor)
            #if os(iOS)
                .buttonStyle(.plain)
            #endif
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                BookLinks(book: book)
            } label: {
                ToolbarActionButton()
            }
            .tint(.primary)
            .menuIndicator(.hidden)
        }
    }

    func toggleMonitor() async {
        let monitored = !book.monitored

        togglingMonitor = true
        defer { togglingMonitor = false }

        guard await instance.books.monitor([book.id], monitored) else { return }

        dependencies.toast.show(monitored ? .monitored : .unmonitored)
    }

    func loadSeries() async {
        guard book.exists, book.authorId > 0, series.isEmpty else { return }
        guard book.foreignBookId?.isEmpty == false else { return }

        if let cached = instance.books.series(book.authorId) {
            series = cached

            return
        }

        let fetched = await instance.books.fetchSeries(book.authorId)

        withAnimation(.snappy) {
            series = fetched
        }
    }

    func loadDetails() async {
        guard book.exists, book.overview == nil || book.rootFolderPath == nil else { return }

        guard let fetched = try? await dependencies.api.chaptarr.book(book.id, instance.books.instance) else {
            return
        }

        withAnimation(.snappy) {
            book.attach(overview: fetched.overview)
            book.attach(author: fetched.author)
        }
    }

    var header: some View {
        HStack(alignment: .top, spacing: 16) {
            poster

            VStack(alignment: .leading, spacing: 0) {
                if book.exists {
                    state
                }

                title
                    .padding(.bottom, 6)

                metadata
                rating

                if deviceType != .phone, book.exists {
                    Spacer()
                    actions
                }
            }

            Spacer()
        }
    }

    var state: some View {
        Text(book.stateLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(settings.theme.tint)
    }

    var title: some View {
        Text(book.title)
            .font(deviceType == .phone && book.title.count > 25 ? .title : .largeTitle)
            .fontWeight(.bold)
            .lineLimit(3)
            .kerning(-0.5)
            .textSelection(.enabled)
    }

    @ViewBuilder
    var metadata: some View {
        if let pages = book.pageCountLabel {
            Text(pages)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    var rating: some View {
        if let value = book.ratings?.value, value > 0 {
            HStack(spacing: 4) {
                Image(systemName: "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)
                    .symbolVariant(.fill)
                    .foregroundStyle(.red)

                Text(value.formatted(.decimal(1)))
                    .lineLimit(1)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
        }
    }

    var poster: some View {
        Color.card
            .modifier(MediaDetailsPosterModifier(ratio: book.posterHeightRatio))
            .overlay { posterBackdrop }
            .overlay { posterImage }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var posterBackdrop: some View {
        CachedAsyncImage(.album, book.remotePoster, placeholder: book.title)
            .scaledToFill()
            .scaleEffect(1.2)
            .blur(radius: 20)
    }

    var posterImage: some View {
        CachedAsyncImage(.album, book.remotePoster, placeholder: book.title)
            .scaledToFit()
            .shadow(radius: 6)
    }

    func description(_ overview: String) -> some View {
        HStack(alignment: .top) {
            Text(descriptionTruncated ? overview.singleLined() : overview)
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.snappy) { descriptionTruncated.toggle() }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = deviceType == .phone
        }
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "books")

    NavigationStack {
        BookView(book: .constant(books[0]))
    }
    .withChaptarrInstance(books: books)
    .withAppState()
}
