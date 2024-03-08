import SwiftUI
import StoreKit

struct SettingsPreferencesSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var entitledToService: Bool = false
    @State private var showSubscriptionSheet: Bool = false
    @State private var showManageScriptionSheet: Bool = false

    var body: some View {
        Section {
            appearancePicker
            themePicker
            iconPicker

            if entitledToService {
                manageSubscription
            }
        } header: {
            Text("Preferences")
        }
        .subscriptionStatusTask(
            for: Subscription.group,
            action: handleSubscriptionStatusChange
        )
        .manageSubscriptionsSheet(
            isPresented: $showManageScriptionSheet,
            subscriptionGroupID: Subscription.group
        )
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

    var manageSubscription: some View {
        Button {
            showManageScriptionSheet = true
        } label: {
            NavigationLink(destination: EmptyView()) {
                Label {
                    Text("Manage Subscription")
                } icon: {
                    Image(systemName: "goforward.plus")
                        .foregroundStyle(.teal)
                }
            }
        }
        .foregroundColor(Color(uiColor: .label))
    }

    func handleSubscriptionStatusChange(
        taskState: EntitlementTaskState<[Product.SubscriptionInfo.Status]>
    ) async {
        switch taskState {
        case .success(let statuses):
            entitledToService = Subscription.containsEntitledState(statuses)
            showSubscriptionSheet = false
        case .failure(let error):
            leaveBreadcrumb(.fatal, category: "subscription", message: "SubscriptionStatusTask failed", data: ["error": error])
            entitledToService = false
        case .loading: break
        @unknown default: break
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
