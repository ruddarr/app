import SwiftUI
import Sentry

struct BookPreviewView: View {
    @State var book: Book

    @State private var presentingForm: Bool = false

    @Environment(AppSettings.self) private var settings
    @Environment(ChaptarrInstance.self) private var instance
    @Environment(\.deviceType) private var deviceType

    @AppStorage("bookDefaults", store: dependencies.store) var bookDefaults: BookDefaults = .init()

    var body: some View {
        BookView(book: $book)
            .toolbar {
                toolbarNextButton
            }
            .sheet(isPresented: $presentingForm) {
                NavigationStack {
                    BookForm(book: $book)
                        .toolbar {
                            toolbarCancelButton
                            toolbarSaveButton
                        }
                        #if os(iOS)
                            .padding(.top, -25)
                        #endif
                }
                .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
                .presentationBackground(.sheetBackground)
            }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presentingForm = false
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .hideIconOnMac()
            }
            .tint(.primary)
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Book", systemImage: "plus") {
                presentingForm = true
            }
            .hideIconOnMac()
            .buttonStyle(.glassProminent)
            .disabled(presentingForm)
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await addBook()
                }
            } label: {
                if instance.books.isWorking {
                    ButtonProgressView()
                } else {
                    Label("Add Book", systemImage: "checkmark")
                        .hideIconOnMac()
                }
            }
            .prominentGlassButtonStyle(!instance.books.isWorking)
            .disabled(saveDisabled)
        }
    }

    var saveDisabled: Bool {
        instance.books.isWorking
            || instance.rootFolders.isEmpty
            || instance.qualityProfiles.isEmpty
            || instance.metadataProfiles.isEmpty
    }

    func addBook() async {
        bookDefaults = .init(from: book)

        var payload = book
        payload.prepareForAdd(searchForNewBook: false)

        guard await instance.books.add(payload) else {
            leaveBreadcrumb(.error, category: "view.book.preview", message: "Failed to add book", data: ["error": instance.books.error ?? ""])

            return
        }

        guard let added = instance.books.items.last, added.exists else {
            return
        }

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        presentingForm = false

        if !dependencies.router.booksPath.isEmpty {
            dependencies.router.booksPath.removeLast()
        }

        try? await Task.sleep(for: .milliseconds(50))
        dependencies.router.booksPath.append(BooksPath.book(added.id))

        maybeAskForReview()
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "book-lookup")

    dependencies.router.selectedTab = .books

    dependencies.router.booksPath.append(
        BooksPath.preview(
            try? JSONEncoder().encode(books[0])
        )
    )

    return ContentView()
        .withChaptarrInstance(books: books)
        .withAppState()
        .macPreviewFrame()
}
