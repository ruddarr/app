import SwiftUI
import StoreKit

struct IconsView: View {
    @EnvironmentObject var settings: AppSettings

    @State var showSubscription: Bool = false
    @State var entitledToService: Bool = false

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 15) {
                ForEach(AppIcon.allCases) { icon in
                    renderIcon(icon)
                }
            }
            .padding(.top)
            .viewPadding(.horizontal)
        }
        .navigationTitle("Icons")
        .safeNavigationBarTitleDisplayMode(.inline)
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
            Image(icon.preview)
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
                    if !icon.locked || entitledToService {
                        settings.icon = icon

                        #if os(iOS)
                            UIApplication.shared.setAlternateIconName(icon.asset)
                        #endif
                    } else {
                        showSubscription = true
                    }
                }

            Text(icon.label)
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
            entitledToService = Subscription.containsEntitledState(statuses)
            showSubscription = false
        case .failure(let error):
            leaveBreadcrumb(.error, category: "subscription", message: "SubscriptionStatusTask failed", data: ["error": error])
            entitledToService = false
        case .loading:
            break
        @unknown default:
            break
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
