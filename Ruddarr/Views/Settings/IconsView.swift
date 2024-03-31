import SwiftUI
import StoreKit

struct IconsView: View {
    @EnvironmentObject var settings: AppSettings

    @State var showSubscription: Bool = false
    @State var entitledToService: Bool = false

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120))]

    // DEBUG: START
    @State var logLines: [String] = []
    @State var showSubscriptionSheet: Bool = false
    @State var showManageScriptionSheet: Bool = false
    // DEBUG: END

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 15) {
                ForEach(AppIcon.allCases) { icon in
                    renderIcon(icon)
                }
            }
            .padding(.top)
            .viewPadding(.horizontal)

            // DEBUG: START
            VStack {
                Button("Manage Subscription") {
                    showManageScriptionSheet = true
                }
                .manageSubscriptionsSheet(
                    isPresented: $showManageScriptionSheet,
                    subscriptionGroupID: Subscription.group
                )

                Button("Subscribe") {
                    showSubscriptionSheet = true
                }
                .sheet(isPresented: $showSubscriptionSheet) {
                    SubscriptionStoreView(groupID: Subscription.group, visibleRelationships: .all) {
                        RuddarrPlusSheetContent()
                    }
                    .subscriptionStoreButtonLabel(.action)
                    .storeButton(.visible, for: .restorePurchases)
                    .tint(.blue)
                    .onInAppPurchaseStart { product in
                        logLines.append("onInAppPurchaseStart")
                        logLines.append("\(product)")
                    }
                    .onInAppPurchaseCompletion { product, result in
                        logLines.append("onInAppPurchaseCompletion")
                        logLines.append("\(product)")
                        logLines.append("\(result)")
                    }
                }
            }
            .font(.footnote)
            .padding(.top)
            .viewPadding(.horizontal)

            if !logLines.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(logLines, id: \.self) { line in
                            Text(line).textSelection(.enabled)
                            Divider()
                        }
                    }
                }
                .font(.caption2)
                .padding(.top)
            }
            // DEBUG: END
        }
        .navigationTitle("Icons")
        .navigationBarTitleDisplayMode(.inline)
        .subscriptionStatusTask(
            for: Subscription.group,
            action: handleSubscriptionStatusChange
        )
        .sheet(isPresented: $showSubscription) {
            RuddarrPlusSheet()
        }
    }

    let strokeWidth: CGFloat = 2
    let iconSize: CGFloat = 64
    var iconRadius: CGFloat { (10 / 57) * iconSize }

    func renderIcon(_ icon: AppIcon) -> some View {
        VStack {
            Image(uiImage: icon.data.uiImage)
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .clipShape(.rect(cornerRadius: iconRadius))
                .padding([.all], 3)
                .overlay {
                    if settings.icon == icon {
                        RoundedRectangle(cornerRadius: iconRadius + 3)
                            .stroke(.primary, lineWidth: strokeWidth)
                    }
                }
                .onTapGesture {
                    if !icon.data.locked || entitledToService {
                        settings.icon = icon
                        UIApplication.shared.setAlternateIconName(icon.data.value)
                    } else {
                        showSubscription = true
                    }
                }

            Text(icon.data.label)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .overlay(alignment: .topTrailing) {
            if icon.data.locked && !entitledToService {
                Image(systemName: "lock")
                    .symbolVariant(.circle.fill)
                    .foregroundStyle(.white, settings.theme.safeTint)
                    .imageScale(.large)
                    .background(Circle().fill(.systemBackground))
                    .offset(x: 3, y: -6)
            }
        }
    }

    func handleSubscriptionStatusChange(
        taskState: EntitlementTaskState<[Product.SubscriptionInfo.Status]>
    ) async {
        switch taskState {
        case .success(let statuses):
            logLines.append("statuses: \(statuses.count)")

            for status in statuses {
                let statusLabel = switch status.state {
                case .subscribed: "subscribed"
                case .expired: "expired"
                case .inBillingRetryPeriod: "inBillingRetryPeriod"
                case .inGracePeriod: "inGracePeriod"
                case .revoked: "revoked"
                default: "default"
                }

                logLines.append("status: \(statusLabel)")
                logLines.append("\(status)")
            }

            entitledToService = Subscription.containsEntitledState(statuses)
            showSubscription = false
        case .failure(let error):
            logLines.append("\(error)")
            leaveBreadcrumb(.error, category: "subscription", message: "SubscriptionStatusTask failed", data: ["error": error])
            entitledToService = false
        case .loading:
            logLines.append("loading")
            break
        @unknown default: break
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.icons
    )

    return ContentView()
        .withAppState()
}
