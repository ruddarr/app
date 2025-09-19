import SwiftUI
import StoreKit

struct SettingsDisplaySection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

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

    var appearancePicker: some View {
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
                .labelStyle(SettingsIconLabelStyle())
        }.tint(.secondary)
    }

    var themePicker: some View {
        Picker(selection: $settings.theme) {
            ForEach(Theme.allCases) { theme in
                Text(verbatim: theme.label)
            }
        } label: {
            Label("Accent Color", systemImage: "paintpalette")
                .labelStyle(SettingsIconLabelStyle())
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
                    .labelStyle(SettingsIconLabelStyle(font: .body))
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
