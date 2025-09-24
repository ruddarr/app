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
                HStack {
                    Circle()
                        .fill(theme.tint)
                        .frame(width: 16, height: 16)
                    Text(verbatim: theme.label)
                }
                .tag(theme)
            }
        } label: {
            Label("Accent Color", systemImage: "paintpalette")
                .labelStyle(SettingsIconLabelStyle(iconScale: 0.85))
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
                    .labelStyle(SettingsIconLabelStyle(iconScale: 1.05))
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
