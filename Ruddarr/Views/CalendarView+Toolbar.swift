import SwiftUI

extension CalendarView {
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

    @ToolbarContentBuilder
    var errorIndicator: some ToolbarContent {
        if !calendar.dates.isEmpty && (!calendar.errors.isEmpty || isRetrying) {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        isRetrying = true
                        await load(force: true)
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                    } else {
                        Label("Error", systemImage: "externaldrive.trianglebadge.exclamationmark")
                    }
                }
                .tint(isRetrying ? .primary : .red)
                .contentTransition(.symbolEffect)
                .disabled(isRetrying)
            }

            ToolbarSpacer(placement: .primaryAction)
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
                Text("Any Instance").tag(String.all)

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
