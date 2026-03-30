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
            gridPicker
            releaseFiltersPicker

            if ![.unknown, .notSubscribed].contains(subscriptionStatus) {
                manageSubscription
            }
        } header: {
            Text("Preferences")
        } footer: {
            footer
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
            Label(
                String(localized: "Home", comment: "(Preferences) Home tab"),
                systemImage: "house"
            )
            .labelStyle(SettingsIconLabelStyle())
        }
        .tint(.secondary)
        .onChange(of: settings.theme) {
            dependencies.router.reset()
        }
    }

    var gridPicker: some View {
        Picker(selection: $settings.grid) {
            ForEach(GridStyle.allCases) { style in
                Text(style.label)
            }
        } label: {
            Label("Grid", systemImage: "square.grid.2x2")
                .labelStyle(SettingsIconLabelStyle())
        }.tint(.secondary)
    }

    var releaseFiltersPicker: some View {
        Picker(selection: $settings.releaseFilters) {
            ForEach(ReleaseFilters.allCases) { value in
                Text(value.label)
            }
        } label: {
            Label("Release Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(SettingsIconLabelStyle())
        }
        .tint(.secondary)
    }

    var manageSubscription: some View {
        #if os(macOS)
            Link(destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!) {
                Label {
                    LabeledContent("Subscription") {
                        Text(subscriptionStatus.label)
                    }
                } icon: {
                    Image(systemName: "bubbles.and.sparkles")
                }
                .labelStyle(SettingsIconLabelStyle())
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
                        Image(systemName: "bubbles.and.sparkles")
                    }
                    .labelStyle(SettingsIconLabelStyle())
                }
            }
            .foregroundStyle(.label)
        #endif
    }

    var footer: some View {
        #if os(macOS)
            let settingsPath = String(localized: "System Settings > General > Language & Region", comment: "macOS notifications path")
        #else
            let settingsPath = String(localized: "System Settings", comment: "Settings app name")
        #endif

        let text = String(
            format: String(localized: "Preferred language and other app-related settings can be configured in the %@."),
            "[\(settingsPath)](#link)"
        )

        return Text(text.toMarkdown()).environment(\.openURL, .init { _ in
            #if os(macOS)
                if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            #else
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
