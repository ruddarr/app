import SwiftUI

extension BookView {
    var bookSeries: BookSeries? {
        guard let key = book.foreignBookId, !key.isEmpty else { return nil }

        let listed = series.filter { $0.lists(key) }

        guard listed.count > 1 else { return listed.first }

        let specific = listed.filter { !isUmbrella($0) }

        return (specific.isEmpty ? listed : specific).min { $0.books.count < $1.books.count }
    }

    var seriesLabel: String? {
        if let title = book.seriesTitle?.trimmed(), !title.isEmpty {
            return title
        }

        guard let bookSeries else { return nil }

        guard let key = book.foreignBookId,
              let entry = bookSeries.books.first(where: { $0.foreignBookId == key }),
              !entry.position.isEmpty
        else {
            return bookSeries.title
        }

        return "\(bookSeries.title) #\(entry.position)"
    }

    func isUmbrella(_ candidate: BookSeries) -> Bool {
        let keys = candidate.bookKeys

        return series.contains { other in
            other.id != candidate.id
                && !other.bookKeys.isEmpty
                && other.bookKeys.isStrictSubset(of: keys)
        }
    }

    func seriesSection(_ series: BookSeries) -> some View {
        Section {
            if seriesExpanded {
                seriesList(series)
                    .padding(.top, 8)
            }
        } header: {
            HStack {
                Text(series.title)
                    .font(.title2.bold())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(seriesExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation { seriesExpanded.toggle() }
            }
        }
    }

    func seriesList(_ series: BookSeries) -> some View {
        let library = Dictionary(
            instance.books.items.compactMap { book -> (String, Book)? in
                guard let key = book.foreignBookId, !key.isEmpty else { return nil }
                return (key, book)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return VStack(spacing: 12) {
            ForEach(Array(series.sortedBooks.enumerated()), id: \.offset) { index, book in
                if index > 0 {
                    Divider()
                }

                let inLibrary = book.libraryKey.flatMap { library[$0] }

                if let inLibrary, inLibrary.id != self.book.id {
                    NavigationLink(value: BooksPath.book(inLibrary.id)) {
                        seriesRow(book, inLibrary: inLibrary, widest: series.widestPosition)
                    }
                    .buttonStyle(.plain)
                } else {
                    seriesRow(book, inLibrary: inLibrary, widest: series.widestPosition)
                }
            }
        }
        .font(.subheadline)
    }

    func seriesRow(_ book: BookSeriesBook, inLibrary: Book?, widest: String) -> some View {
        let current = inLibrary?.id == self.book.id

        return HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                Text(widest).hidden()
                Text(book.positionLabel)
            }
            .monospacedDigit()
            .foregroundStyle(current ? settings.theme.tint : Color.secondary)

            Text(book.title)
                .lineLimit(1)
                .fontWeight(current ? .semibold : .regular)
                .foregroundStyle(current ? settings.theme.tint : Color.primary)

            Spacer()

            if let inLibrary {
                seriesMonitorButton(inLibrary)
            }
        }
        .contentShape(Rectangle())
    }

    func seriesMonitorButton(_ book: Book) -> some View {
        Button {
            Task { await toggleSeriesMonitor(book) }
        } label: {
            RowMonitorButton(
                monitored: book.monitored,
                loading: instance.books.isMonitoring == book.id
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(instance.books.isMonitoring == 0)
    }

    func toggleSeriesMonitor(_ book: Book) async {
        guard let index = instance.books.items.firstIndex(where: { $0.id == book.id }) else {
            return
        }

        let original = instance.books.items[index].monitored
        instance.books.items[index].monitored = !original

        guard await instance.books.monitor([book.id], !original) else {
            instance.books.items.revert(\.monitored, to: original, id: book.id)

            return
        }

        dependencies.toast.show(!original ? .monitored : .unmonitored)
    }

    var information: some View {
        Section {
            Information(items: informationItems)
                .font(.subheadline)
        } header: {
            HStack {
                Text("Information")
                    .font(.title2.bold())

                Spacer()

                NavigationLink(
                    "Files & History",
                    value: BooksPath.metadata(book.id)
                )
                .font(.callout)
            }
        }
    }

    var informationItems: [InformationItem] {
        var items: [InformationItem] = []

        if let mediaType = book.mediaType, !mediaType.isEmpty {
            items.append(InformationItem(
                label: String(localized: "Format", comment: "Audiobook or eBook"),
                value: mediaType.capitalized
            ))
        }

        if let rootFolder = book.rootFolderPath {
            items.append(InformationItem(
                label: String(localized: "Root Folder"),
                value: rootFolder
            ))
        }

        if let releaseDate = book.releaseDate {
            items.append(InformationItem(
                label: String(localized: "Release Date"),
                value: releaseDate.formatted(date: .abbreviated, time: .omitted)
            ))
        }

        return items
    }

    var actions: some View {
        HStack(spacing: 20) {
            Button { } label: {
                ButtonLabel(text: String(localized: "Automatic"), icon: "magnifyingglass")
            }
            .actionButton()
            .actionButtonWidth()

            Button { } label: {
                ButtonLabel(text: String(localized: "Interactive"), icon: "person.fill")
            }
            .actionButton()
            .actionButtonWidth()
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: deviceType == .phone ? .center : .leading)
    }

    var details: some View {
        Grid(alignment: .leading) {
            if let author = book.authorLabel {
                MediaDetailsRow(String(localized: "Author"), value: author)
            }

            if let narrator = book.narrator, !narrator.isEmpty {
                MediaDetailsRow(
                    String(localized: "Narrator", comment: "The narrator of an audiobook"),
                    value: narrator
                )
            }

            if let series = seriesLabel {
                MediaDetailsRow(String(localized: "Series"), value: series)
            }

            if !book.genres.isEmpty {
                MediaDetailsRow(String(localized: "Genre"), value: book.genreLabel)
            }

            if let duration = book.durationLabel {
                MediaDetailsRow(String(localized: "Runtime"), value: duration)
            }
        }
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "books")

    dependencies.router.selectedTab = .books

    dependencies.router.booksPath.append(
        BooksPath.book(books[0].id)
    )

    return ContentView()
        .withChaptarrInstance(books: books)
        .withAppState()
}
