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

            #if os(iOS)
                iconPicker

                if ![.unknown, .notSubscribed].contains(subscriptionStatus) {
                    manageSubscription
                }
            #endif
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

    var tabPicker: some View {
        Picker(selection: $settings.tab) {
            ForEach([
                TabItem.movies,
                TabItem.series,
                TabItem.calendar,
                TabItem.activity,
            ]) { tab in
                Text(tab.label)
            }
        } label: {
            Label("Home", systemImage: "house")
                .labelStyle(SettingsIconLabelStyle(color: .gray))
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
                }
                .labelStyle(SettingsIconLabelStyle(color: .orange))
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

struct SettingsIconLabelStyle: LabelStyle {
    var color: Color
    @ScaledMetric(relativeTo: .body) var size: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var iconSize = 28

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .tint(.primary)
        } icon: {
            configuration.icon
                .font(.system(size: size))
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: (10 / 57) * iconSize)
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(color)
                )
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
