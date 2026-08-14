import SwiftUI

struct BookForm: View {
    @Binding var book: Book

    @Environment(AppSettings.self) private var settings
    @Environment(ChaptarrInstance.self) private var instance

    @State private var defaultsSet = false
    @State private var format: BookFormat = .audiobook

    let mediaType: BookSort.BookMediaType = .audiobook

    enum BookFormat: CaseIterable, Identifiable {
        case audiobook
        case both
        case ebook

        var id: Self { self }

        var label: some View {
            switch self {
            case .audiobook: Label(String(localized: "Audiobooks", comment: "Media grid format"), systemImage: "headphones")
            case .both: Label(String(localized: "Both", comment: "Audiobooks and eBooks"), systemImage: "square.stack")
            case .ebook: Label(String(localized: "eBooks", comment: "Media grid format"), systemImage: "book")
            }
        }
    }

    @AppStorage("bookDefaults", store: dependencies.store) var bookDefaults: BookDefaults = .init()

    var body: some View {
        Form {
            Section {
                mediaTypeField
            }

            Section {
                qualityProfileField
                metadataProfileField

                Toggle("Monitor New Books", isOn: $book.audiobookMonitorFuture)
                    .tint(settings.theme.safeTint)

                if !instance.tags.isEmpty {
                    tagsField
                }
            } header: {
                Text("Audiobooks", comment: "Media grid format")
            }

            if instance.rootFolders.count > 1 {
                rootFolderField
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectDefaultValues()
        }
    }

    var qualityProfiles: [InstanceQualityProfile] {
        instance.qualityProfiles.filter(mediaType.matches)
    }

    var metadataProfiles: [InstanceMetadataProfile] {
        instance.metadataProfiles.filter(mediaType.matches)
    }

    var mediaTypeField: some View {
        Picker(selection: $format) {
            ForEach(BookFormat.allCases) { format in
                format.label.tag(format)
            }
        } label: {
            Text("Format", comment: "Audiobook or eBook")
        }
        .tint(.secondary)
        .disabled(true)
    }

    @ViewBuilder
    var qualityProfileField: some View {
        if qualityProfiles.isEmpty {
            LabeledContent("Quality Profile") {
                Text("Error")
            }
        } else {
            Picker(selection: $book.audiobookQualityProfileId) {
                ForEach(qualityProfiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    Text("Quality Profile")
                    Text("Quality")
                }
            }
            .tint(.secondary)
        }
    }

    @ViewBuilder
    var metadataProfileField: some View {
        if metadataProfiles.isEmpty {
            LabeledContent("Metadata Profile") {
                Text("Error")
            }
        } else {
            Picker(selection: $book.audiobookMetadataProfileId) {
                ForEach(metadataProfiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    Text("Metadata Profile")
                    Text("Metadata")
                }
            }
            .tint(.secondary)
        }
    }

#if os(macOS)
    var tagsField: some View {
        LabeledContent("Tags") {
            TagMenu(selected: tags(), tags: instance.tags)
        }
    }
#else
    var tagsField: some View {
        NavigationLink {
            TagList(selected: tags(), tags: instance.tags)
        } label: {
            LabeledContent("Tags") {
                Text(book.authorTags.isEmpty ? "None" : "\(book.authorTags.count) Tag")
            }
        }
    }
#endif

    var rootFolderField: some View {
        Picker("Root Folder", selection: $book.audiobookRootFolderPath) {
            ForEach(instance.rootFolders) { folder in
                folder.labelWithSpace
                    .tag(folder.path ?? "")
            }
        }
        .pickerStyle(.inline)
        .tint(settings.theme.tint)
        .accentColor(settings.theme.tint) // `.tint()` is broken on inline pickers
    }

    func selectDefaultValues() {
        guard !defaultsSet else { return }
        defaultsSet = true

        book.audiobookRootFolderPath = bookDefaults.rootFolder
        book.audiobookQualityProfileId = bookDefaults.qualityProfile
        book.audiobookMetadataProfileId = bookDefaults.metadataProfile
        book.audiobookMonitorFuture = bookDefaults.monitorNewBooks

        if !qualityProfiles.contains(where: { $0.id == book.audiobookQualityProfileId }) {
            book.audiobookQualityProfileId = qualityProfiles.first?.id ?? 0
        }

        if !metadataProfiles.contains(where: { $0.id == book.audiobookMetadataProfileId }) {
            book.audiobookMetadataProfileId = metadataProfiles.first?.id ?? 0
        }

        book.audiobookRootFolderPath = book.audiobookRootFolderPath.untrailingSlashIt ?? ""

        if let fallback = instance.rootFolders.first?.path,
           !instance.rootFolders.contains(where: {
               $0.path?.untrailingSlashIt == book.audiobookRootFolderPath
           }) {
            book.audiobookRootFolderPath = fallback
        }
    }

    func tags() -> Binding<Set<Tag.ID>> {
        Binding(
            get: { Set(book.authorTags) },
            set: { book.authorTags = Array($0) }
        )
    }
}

#Preview {
    let books: [Book] = PreviewData.load(name: "book-lookup")
    let book = books[0]

    NavigationStack {
        BookForm(book: Binding(get: { book }, set: { _ in }))
    }
    .withChaptarrInstance(books: books)
    .withAppState()
}
