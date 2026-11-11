import SwiftUI

/// "Add Condition", a menu of fields in sections, and the live match count below it.
struct CustomFilterEditorAddSection<Item: CustomFilterable>: View {
    let items: [Item]
    let filter: CustomFilter
    let onAdd: (CustomFilterField) -> Void

    /// How many items match the filled-in conditions, counted off the main thread. `nil` until first counted.
    @State private var matching: Int?

    var body: some View {
        Section {
            Menu {
                CustomFilterFieldPickerContent(fields: Item.customFilterFields) { field in
                    Button(field.label) { onAdd(field) }
                }
            } label: {
                Label("Add Condition", systemImage: "plus.circle")
            }
            #if os(macOS)
                .menuStyle(.borderlessButton)
                .fixedSize()
            #endif
            .task(id: filter.conditions) {
                await countMatches()
            }
        } footer: {
            matchCount
        }
    }

    @ViewBuilder
    var matchCount: some View {
        if !filter.isSupported(for: Item.self) {
            Text("Matches can't be counted, because \(Ruddarr.name) can't check every condition.")
        } else if !filter.conditions.isEmpty, let matching {
            Text(Self.matchCountText(matching, of: items.count))
                .contentTransition(.numericText())
                .animation(.default, value: matching)
        }
    }

    /// Recounts after a short pause, so typing a value doesn't count on every keystroke.
    /// `.task(id:)` cancels a count whose conditions have since changed.
    func countMatches() async {
        guard filter.isSupported(for: Item.self), !filter.conditions.isEmpty else { return }

        if matching != nil {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
        }

        // Conditions without a value yet are left out, so the count follows what's filled in.
        let counted = CustomFilter(id: filter.id, label: filter.label, conditions: filter.conditions.filter { !$0.value.isEmptyValue })
        let count = await Self.count(counted, in: items)

        guard !Task.isCancelled else { return }
        matching = count
    }

    @concurrent nonisolated private static func count(_ filter: CustomFilter, in items: [Item]) async -> Int {
        let now = Date.now
        let gregorian = Calendar.gregorian(in: .current)

        return items.count { filter.matches($0, now: now, calendar: gregorian) }
    }

    static func matchCountText(_ matching: Int, of total: Int) -> String {
        Item.self == Series.self
            ? String(localized: "Matches \(matching) of \(total) series")
            : String(localized: "Matches \(matching) of \(total) movies")
    }
}

/// Where the filter is saved: on the server, or on this device only.
struct CustomFilterEditorStorageSection: View {
    let serverName: String
    @Binding var onServer: Bool
    /// Whether an existing server filter is being moved to this device.
    let isMovingToDevice: Bool

    var body: some View {
        Section {
            Picker("Saved in", selection: $onServer) {
                Text(verbatim: serverName).tag(true)
                Text("This Device").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            Text("Saved in")
        } footer: {
            if isMovingToDevice {
                Text("This filter will be removed from the \(serverName) web interface and other devices, and only saved on this device.")
            } else if onServer {
                Text("Also shows the filter in the \(serverName) web interface and in \(Ruddarr.name) on other devices.")
            } else {
                Text("Only shows the filter in \(Ruddarr.name) on this device.")
            }
        }
    }
}
