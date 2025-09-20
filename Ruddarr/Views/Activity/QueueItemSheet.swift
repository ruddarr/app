import SwiftUI

struct QueueItemSheet: View {
    var item: QueueItem

    @EnvironmentObject var settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.deviceType) private var deviceType

    @State private var timeRemaining: String?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                CloseButton {
                    dismiss()
                }

                ScrollView {
                    VStack(alignment: .leading) {
                        header

                        if item.remainingLabel != nil {
                            progress
                                .padding(.top)
                        }

                        actions
                            .padding(.vertical)

                        if let error = item.errorMessage, !error.isEmpty {
                            LabeledGroupBox {
                                Text(error)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .padding(.bottom)
                        } else if !item.messages.isEmpty {
                            LabeledGroupBox {
                                statusMessages
                            }.padding(.bottom)
                        }

                        details
                    }
                    .viewPadding(.horizontal)
                    .padding(.top)
                    .padding(.top)
                }
            }
        }
    }

    @ViewBuilder
    var header: some View {
        Text(item.extendedStatusLabel)
            .foregroundStyle(settings.theme.tint)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(1.1)

        Text(item.title?.breakable() ?? "Unknown")
            .font(.title3.bold())
            .kerning(-0.5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.trailing, 40)

        HStack(spacing: 6) {
            Text(item.quality.quality.label)
            Bullet()
            Text(formatBytes(Int(item.size)))
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        CustomFormats(tags)
    }

    var statusMessages: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(item.messages, id: \.self) { status in
                VStack(alignment: .leading) {
                    Text(status.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(status.messages, id: \.self) { message in
                        Text(message)
                            .font(.footnote.italic())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var progress: some View {
        ProgressView(value: item.size - item.sizeleft, total: item.size) {
            HStack {
                Text(item.progressLabel)
                Spacer()
                Text(timeRemaining ?? "")
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .onReceive(timer) { _ in
            timeRemaining = item.remainingLabel
        }
    }

    var details: some View {
        Section {
            VStack(spacing: 6) {
                row("Language", item.languagesLabel)

                if let indexer = item.indexer {
                    Divider()
                    row("Indexer", formatIndexer(indexer))
                }

                Divider()
                row("Protocol", item.type.label)

                if let client = item.downloadClient {
                    Divider()
                    row("Client", client)
                }

                if let date = item.added {
                    Divider()
                    row("Added", date.formatted(date: .long, time: .shortened))
                }
            }
            .padding(.bottom)
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            NavigationLink {
                TaskRemovalView(item: item, onRemove: { dismiss() })
                    .environmentObject(settings)
            } label: {
                let label: String = deviceType == .phone
                    ? String(localized: "Remove", comment: "(Short) Removing a queue task")
                    : String(localized: "Remove Task")

                ButtonLabel(text: label, icon: "trash")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.glass)

            if item.needsManualImport {
                NavigationLink {
                    TaskImportView(item: item, onRemove: { dismiss() })
                        .environmentObject(settings)
                } label: {
                    let label: String = deviceType == .phone
                        ? String(localized: "Import", comment: "(Short) Importing a queue task")
                        : String(localized: "Manual Import")

                    ButtonLabel(text: label, icon: "square.and.arrow.down")
                        .modifier(MediaPreviewActionModifier())
                }
                .buttonStyle(.glass)
            } else if item.isSABnzbd && sableInstalled() {
                sableLink
            } else if item.isDownloadStation && dsloadInstalled() {
                sableLink
            } else {
                Spacer()
                    .modifier(MediaPreviewActionSpacerModifier())
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var tags: [String] {
        var tags: [String] = []

        if let score = item.scoreLabel {
            tags.append(score)
        }

        if let formats = item.customFormats, !formats.isEmpty {
            tags.append(contentsOf: formats.map { $0.label })
        }

        return tags
    }

    func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        row(label, Text(value).foregroundStyle(.primary))
    }

    func row<V: View>(_ label: LocalizedStringKey, _ value: V) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
            Spacer()

            value
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
        .padding(.vertical, 4)
    }

    func parseDate(_ string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }

        return nil
    }

    func formatDate(_ date: Date) -> String {
        date.formatted(date: .long, time: .shortened)
    }

    func sableInstalled() -> Bool {
        #if os(macOS)
            return false
        #else
            return UIApplication.shared.canOpenURL(URL(string: "sable://open")!)
        #endif
    }

    func dsloadInstalled() -> Bool {
        #if os(macOS)
            return false
        #else
            return UIApplication.shared.canOpenURL(URL(string: "dsdownload://")!)
        #endif
    }

    var sableLink: some View {
        Link(destination: URL(string: "sable://open")!, label: {
            ButtonLabel(
                text: deviceType == .phone
                    ? String("Sable")
                    : String(localized: "Open \("Sable")", comment: "Open (app name)"),
                icon: "arrow.up.right.square"
            )
            .modifier(MediaPreviewActionModifier())
        })
        .buttonStyle(.glass)
    }

    var dsloadLink: some View {
        Link(destination: URL(string: "dsdownload://")!, label: {
            ButtonLabel(
                text: deviceType == .phone
                    ? String("DSLoad")
                    : String(localized: "Open \("DSLoad")", comment: "Open (app name)"),
                icon: "arrow.up.right.square"
            )
            .modifier(MediaPreviewActionModifier())
        })
        .buttonStyle(.glass)
    }
}

#Preview {
    let items: QueueItems = PreviewData.loadObject(name: "series-queue")
    let item: QueueItem = items.records[2]

    QueueItemSheet(item: item)
        .withAppState()
}

#Preview("Downloading") {
    let items: QueueItems = PreviewData.loadObject(name: "movie-queue")
    var item: QueueItem = items.records[0]

    item.estimatedCompletionTime = Date.now.addingTimeInterval(90)

    return QueueItemSheet(item: item)
        .withAppState()
}

#Preview("Waiting + Error") {
    let items: QueueItems = PreviewData.loadObject(name: "movie-queue")
    let item = items.records[1]

    QueueItemSheet(item: item)
        .withAppState()
}
