import SwiftUI
import StoreKit

struct SettingsDisplaySection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Section {
            appearancePicker
            themePicker

            #if os(iOS)
                iconPicker
            #endif
        } header: {
            Text("Display", comment: "Preferences section title")
        }
    }

    @ViewBuilder
    var appearancePicker: some View {
        @Bindable var settings = settings

        Picker(selection: $settings.appearance) {
            ForEach(Appearance.allCases) { colorScheme in
                Text(colorScheme.label)
            }
        } label: {
            let icon = switch settings.appearance {
            case .automatic: colorScheme == .dark ? "moon" : "sun.max"
            case .light: "sun.max"
            case .dark: "moon"
            }

            Label("Appearance", systemImage: icon)
                .labelStyle(.settingsIcon)
        }.tint(.secondary)
    }

    @ViewBuilder
    var themePicker: some View {
        @Bindable var settings = settings

        Picker(selection: $settings.theme) {
            ForEach(Theme.allCases) { theme in
                Label {
                    Text(verbatim: theme.label)
                } icon: {
                    Image(systemName: "circle.fill")
                }
                .tint(theme.tint)
            }
        } label: {
            Label("Accent Color", systemImage: "paintpalette")
                .labelStyle(.settingsIcon(iconScale: 0.85))
        } currentValueLabel: {
            Text(verbatim: settings.theme.label)
        }
        .tint(.secondary)
        .onChange(of: settings.theme) {
            dependencies.router.reset()
        }
    }

    var iconPicker: some View {
        NavigationLink(value: SettingsView.Path.icons) {
            LabeledContent {
                Text(settings.icon.label)
            } label: {
                Label("App Icon", systemImage: "app.grid")
                    .labelStyle(.settingsIcon(iconScale: 1.05))
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
