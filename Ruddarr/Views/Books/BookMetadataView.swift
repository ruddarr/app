import SwiftUI

struct BookMetadataView: View {
    var book: Book

    @Environment(ChaptarrInstance.self) private var instance

    @State private var fileSheet: BookFile?
    @State private var eventSheet: MediaHistoryEvent?

    var body: some View {
        ScrollView {
            Group {
                files
                history
            }
            .padding(.vertical)
            .scenePadding(.horizontal)
        }
        .navigationTitle(book.title)
        .safeNavigationBarTitleDisplayMode(.inline)
        .onAppear {
            instance.metadata.setBook(book)
        }
        .refreshable {
            await Task {
                await instance.metadata.refresh(for: book)
            }.value
        }
    }

    var files: some View {
        Section {
            if instance.metadata.filesLoading {
                ProgressView().tint(.secondary)
            } else if instance.metadata.filesError {
                noContent("An error occurred.")
            } else if instance.metadata.files.isEmpty {
                noContent("Book has no files.")
            } else {
                ForEach(instance.metadata.files) { file in
                    BookFilesFile(file: file)
                        .padding(.bottom, 4)
                        .onTapGesture { fileSheet = file }
                }
            }
        } header: {
            Text("Files")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await instance.metadata.fetchFiles(for: book)
        }
        .sheet(item: $fileSheet) { file in
            BookFileSheet(file: file)
                .presentationDetents([.medium])
                .presentationBackground(.sheetBackground)
        }
    }

    var history: some View {
        Section {
            if instance.metadata.historyLoading {
                ProgressView().tint(.secondary)
            } else if instance.metadata.historyError {
                noContent("An error occurred.")
            } else if instance.metadata.history.isEmpty {
                noContent("Book has no history.")
            } else {
                ForEach(instance.metadata.history.filter { $0.bookId == book.id }) { event in
                    MediaHistoryItem(event: event)
                        .padding(.bottom, 4)
                        .onTapGesture { eventSheet = event }
                }
            }
        } header: {
            Text("History")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await instance.metadata.fetchHistory(for: book)
        }
        .sheet(item: $eventSheet) { event in
            MediaEventSheet(event: event)
                .presentationDetents(
                    dynamic: event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
                .presentationBackground(.sheetBackground)
        }
    }

    func noContent(_ label: LocalizedStringKey) -> some View {
        Text(label)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom)
    }
}

struct BookFilesFile: View {
    var file: BookFile

    @Environment(ChaptarrInstance.self) private var instance

    @State private var showDeleteConfirmation = false

    var body: some View {
        LabeledGroupBox {
            HStack(spacing: 6) {
                Text(file.quality.quality.label)

                if let audio = file.audioLabel {
                    Bullet()
                    Text(audio)
                }

                Bullet()
                Text(file.sizeLabel)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } label: {
            Text(file.filenameLabel)
        }
        .contextMenu {
            Button("Delete File", systemImage: "trash", role: .destructive) {
                showDeleteConfirmation = true
            }.tint(.red)
        }
        .alert(
            "Are you sure?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete File", role: .destructive) {
                Task { await deleteFile() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently erase the book file.")
        }.tint(nil)
    }

    func deleteFile() async {
        if await instance.metadata.delete(file) {
            dependencies.toast.show(.fileDeleted)
        }
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "books")

    dependencies.router.selectedTab = .books

    dependencies.router.booksPath.append(
        BooksPath.book(books[0].id)
    )

    dependencies.router.booksPath.append(
        BooksPath.metadata(books[0].id)
    )

    return ContentView()
        .withChaptarrInstance(books: books)
        .withAppState()
}
