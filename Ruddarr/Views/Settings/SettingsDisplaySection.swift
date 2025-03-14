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
            Text("Display")
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
                .labelStyle(SettingsIconLabelStyle(color: .blue))
        }.tint(.secondary)
    }

    var themePicker: some View {
        Picker(selection: $settings.theme) {
            ForEach(Theme.allCases) { theme in
                Text(verbatim: theme.label)
            }
        } label: {
            Label("Accent Color", systemImage: "paintpalette")
                .labelStyle(SettingsIconLabelStyle(color: .teal, size: 13))
        }
        .tint(.secondary)
        .onChange(of: settings.theme) {
            dependencies.router.reset()
        }
    }

    @ScaledMetric(relativeTo: .body) var appIconSize = 28

    var iconPicker: some View {
        NavigationLink(value: SettingsView.Path.icons) {
            Label {
                LabeledContent {
                    Text(settings.icon.label)
                } label: {
                    Text("App Icon")
                }
            } icon: {
                Image(settings.icon.image)
                    .resizable()
                    .frame(width: appIconSize, height: appIconSize)
                    .clipShape(.rect(cornerRadius: (10 / 57) * appIconSize))
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
