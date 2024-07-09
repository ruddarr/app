import SwiftUI
import StoreKit

struct SettingsPreferencesSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var entitledToService: Bool = false
    @State private var subscriptionStatus: SubscriptionStatus = .unknown
    @State private var showSubscriptionSheet: Bool = false
    @State private var showManageSubscriptionSheet: Bool = false

    var body: some View {
        Section {
            tabPicker
            appearancePicker
            themePicker
            iconPicker

            if ![.unknown, .notSubscribed].contains(subscriptionStatus) {
                manageSubscription
            }
        } header: {
            Text("Preferences")
        }
        .subscriptionStatusTask(
            for: Subscription.group,
            action: handleSubscriptionStatusChange
        )
        #if os(iOS)
        .manageSubscriptionsSheet(
            isPresented: $showManageSubscriptionSheet,
            subscriptionGroupID: Subscription.group
        )
        #endif
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
                    .foregroundStyle(Color(.monochrome))
            }
        }.tint(.secondary)
    }

    var themePicker: some View {
        Picker(selection: $settings.theme) {
            ForEach(Theme.allCases) { theme in
                Text(verbatim: theme.label)
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

    @ScaledMetric(relativeTo: .body) var appIconSize = 24

    var iconPicker: some View {
        NavigationLink(value: SettingsView.Path.icons) {
            Label {
                LabeledContent {
                    Text(settings.icon.data.label)
                } label: {
                    Text("App Icon")
                }
            } icon: {
                #if os(macOS)
                    let icon = "AppIcon"
                #else
                    let icon = UIApplication.shared.alternateIconName ?? "AppIcon"
                #endif

                Image(appIcon: icon)
                    .resizable()
                    .frame(width: appIconSize, height: appIconSize)
                    .clipShape(.rect(cornerRadius: (10 / 57) * appIconSize))
            }
        }
    }

    var tabPicker: some View {
        Picker(selection: $settings.tab) {
            ForEach([Tab.movies, Tab.series, Tab.calendar]) { tab in
                Text(tab.text)
            }
        } label: {
            Label {
                Text("Home")
            } icon: {
                Image(systemName: "house")
                    .foregroundStyle(Color(.monochrome))
            }
        }
        .tint(.secondary)
        .onChange(of: settings.theme) {
            dependencies.router.reset()
        }
    }

    var manageSubscription: some View {
        Button {
            showManageSubscriptionSheet = true
        } label: {
            NavigationLink(destination: EmptyView()) {
                Label {
                    LabeledContent {
                        Text(subscriptionStatus.label).foregroundStyle(.secondary)
                    } label: {
                        Text("Subscription")
                    }
                } icon: {
                    Image(systemName: "crown")
                        .symbolVariant(.fill)
                        .foregroundStyle(.yellow)
                }
                .offset(y: -1)
            }
        }
        .foregroundStyle(.label)
    }

    func handleSubscriptionStatusChange(
        taskState: EntitlementTaskState<[Product.SubscriptionInfo.Status]>
    ) async {
        switch taskState {
        case .success(let statuses):
            entitledToService = Subscription.containsEntitledState(statuses)
            subscriptionStatus = Subscription.status(from: statuses)
            showSubscriptionSheet = false

            leaveBreadcrumb(.info, category: "subscription", message: "SubscriptionStatusTask success", data: ["statuses": statuses])
        case .failure(let error):
            entitledToService = false
            subscriptionStatus = .error

            leaveBreadcrumb(.fatal, category: "subscription", message: "SubscriptionStatusTask failed", data: ["error": error])
        case .loading:
            break
        @unknown default:
            subscriptionStatus = .unknown
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
