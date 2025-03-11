import SwiftUI
import StoreKit

struct SettingsPreferencesSection: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showSubscriptionSheet: Bool = false
    @State private var subscriptionStatus: SubscriptionStatus = .unknown

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
            isPresented: $showSubscriptionSheet,
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
            showSubscriptionSheet = true
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
                .labelStyle(SettingsIconLabelStyle(color: .orange, size: 13))
            }
        }
        .foregroundStyle(.label)
    }

    func handleSubscriptionStatusChange(
        taskState: EntitlementTaskState<[Product.SubscriptionInfo.Status]>
    ) async {
        print(taskState)
        switch taskState {
        case .success(let statuses):
            withAnimation {
                subscriptionStatus = Subscription.status(from: statuses)
            }

            leaveBreadcrumb(.info, category: "subscription", message: "SubscriptionStatusTask success", data: ["statuses": statuses])
        case .failure(let error):
            withAnimation {
                subscriptionStatus = .error
            }

            leaveBreadcrumb(.fatal, category: "subscription", message: "SubscriptionStatusTask failed", data: ["error": error])
        case .loading:
            break
        @unknown default:
            withAnimation {
                subscriptionStatus = .unknown
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
