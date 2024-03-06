import SwiftUI

struct SettingsPreferencesSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Section {
            appearancePicker
            themePicker
            iconPicker

        } header: {
            Text("Preferences")
        }
        .tint(.secondary)
    }

    var appearancePicker: some View {
        Picker(selection: $settings.appearance) {
            ForEach(Appearance.allCases) { colorScheme in
                Text(colorScheme.label)
            }
        } label: {
            Label {
                Text("Appearance")
            } icon: {
                let icon = switch settings.appearance {
                case .automatic: colorScheme == .dark ? "moon" : "sun.max"
                case .light: "sun.max"
                case .dark: "moon"
                }

                Image(systemName: icon)
                    .foregroundStyle(Color("Monochrome"))
            }
        }.tint(.secondary)
    }

    var themePicker: some View {
        Picker(selection: $settings.theme) {
            ForEach(Theme.allCases) { theme in
                Text(theme.label)
            }
        } label: {
            Label {
                Text("Accent Color")
            } icon: {
                Image(systemName: "paintpalette")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .tint(.secondary)
        .onChange(of: settings.theme) {
            dependencies.router.reset()
        }
    }

    var iconPicker: some View {
        NavigationLink(value: SettingsView.Path.icons) {
            Label {
                LabeledContent {
                    Text(settings.icon.data.label)
                } label: {
                    Text("App Icon")
                }
            } icon: {
                Image(
                    uiImage: UIImage(named: UIApplication.shared.alternateIconName ?? "AppIcon")!
                )
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(.rect(cornerRadius: (10 / 57) * 24))
            }
        }
    }
}
