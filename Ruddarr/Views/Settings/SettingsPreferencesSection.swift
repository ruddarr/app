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
            releaseFiltersPicker

            #if os(iOS)
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
                .labelStyle(SettingsIconLabelStyle(color: .gray, size: 13))
        }
        .tint(.secondary)
        .onChange(of: settings.theme) {
            dependencies.router.reset()
        }
    }

    var releaseFiltersPicker: some View {
        Picker(selection: $settings.releaseFilters) {
            ForEach(ReleaseFilters.allCases) { value in
                Text(value.label)
            }
        } label: {
            Label("Release Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(SettingsIconLabelStyle(color: .gray, size: 13))
        }
        .tint(.secondary)
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
