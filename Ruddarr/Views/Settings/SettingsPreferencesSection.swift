import SwiftUI
import StoreKit
import Sentry

struct SettingsPreferencesSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSubscriptionSheet: Bool = false
    @AppStorage("subscription", store: dependencies.store) private var subscriptionStatus: SubscriptionStatus = .unknown

    var body: some View {
        Section {
            tabPicker
            gridPicker
            releasesPicker
            releaseFiltersPicker

            if ![.unknown, .notSubscribed].contains(subscriptionStatus) {
                manageSubscription
            }
        } header: {
            Text("Preferences")
        } footer: {
            #if os(iOS)
                footer
            #endif
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

    @ViewBuilder
    var tabPicker: some View {
        @Bindable var settings = settings

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
            Label(
                String(localized: "Home", comment: "(Preferences) Home tab"),
                systemImage: "house"
            )
            .labelStyle(.settingsIcon)
        }
        .tint(.secondary)
    }

    @ViewBuilder
    var gridPicker: some View {
        @Bindable var settings = settings

        Picker(selection: $settings.grid) {
            ForEach(GridStyle.allCases) { style in
                Text(style.label)
            }
        } label: {
            Label("Grid", systemImage: "rectangle.grid.3x2")
                .labelStyle(.settingsIcon)
        }.tint(.secondary)
    }

    @ViewBuilder
    var releasesPicker: some View {
        @Bindable var settings = settings

        Picker(selection: $settings.releases) {
            ForEach(ReleaseLayout.allCases) { value in
                Text(value.label)
            }
        } label: {
            Label("Releases", systemImage: "rectangle.grid.1x3")
                .labelStyle(.settingsIcon)
        }
        .tint(.secondary)
    }

    @ViewBuilder
    var releaseFiltersPicker: some View {
        @Bindable var settings = settings

        Picker(selection: $settings.releaseFilters) {
            ForEach(ReleaseFilters.allCases) { value in
                Text(value.label)
            }
        } label: {
            Label("Release Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.settingsIcon)
        }
        .tint(.secondary)
    }

    @ViewBuilder
    var manageSubscription: some View {
        let icon = Image(systemName: "bubbles.and.sparkles")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.primary, settings.theme.tint)

        #if os(macOS)
            Link(destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!) {
                Label {
                    LabeledContent("Subscription") {
                        Text(subscriptionStatus.label)
                    }
                } icon: {
                    icon
                }
                .labelStyle(.settingsIcon)
            }
            .buttonStyle(.plain)
        #else
            Button {
                showSubscriptionSheet = true
            } label: {
                NavigationLink(destination: EmptyView()) {
                    Label {
                        LabeledContent("Subscription") {
                            Text(subscriptionStatus.label).foregroundStyle(.secondary)
                        }
                    } icon: {
                        icon
                    }
                    .labelStyle(.settingsIcon)
                }
            }
            .foregroundStyle(.label)
        #endif
    }

    var footer: some View {
        let text = String(localized: "Preferred language and other app-related settings can be configured in the [System Settings](#link).")

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            #endif

            return .handled
        })
    }

    func handleSubscriptionStatusChange(
        taskState: EntitlementTaskState<[Product.SubscriptionInfo.Status]>
    ) async {
        switch taskState {
        case .success(let statuses):
            withAnimation {
                subscriptionStatus = Subscription.status(from: statuses)
            }

            // leaveBreadcrumb(.info, category: "subscription", message: "SubscriptionStatusTask success", data: ["statuses": statuses])
        case .failure(let error):
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
