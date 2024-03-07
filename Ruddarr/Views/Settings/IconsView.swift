import SwiftUI
import StoreKit

struct IconsView: View {
    let columns = [GridItem(.adaptive(minimum: 80, maximum: 120))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 15) {
                Icons()
            }
            .padding(.top)
            .viewPadding(.horizontal)
        }
        .navigationTitle("Icons")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Icons: View {
    @EnvironmentObject var settings: AppSettings

    @State var showSubscription: Bool = false
    @State var entitledToService: Bool = false

    let iconSize: CGFloat = 64
    var iconRadius: CGFloat { (10 / 57) * iconSize }
    let strokeWidth: CGFloat = 2

    var body: some View {
        ForEach(AppIcon.allCases) { icon in
            VStack {
                Image(uiImage: icon.data.uiImage)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(.rect(cornerRadius: iconRadius))
                    .padding([.all], 3)
                    .overlay {
                        if settings.icon == icon {
                            currentOverlay
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
            }
            .overlay(alignment: .topTrailing) {
                if icon.data.locked && !entitledToService {
                    lockOverlay
                }
            }
        }
        .subscriptionStatusTask(for: Subscription.group, action: handleSubscriptionStatusChange)
        .sheet(isPresented: $showSubscription) { RuddarrPlusSheet() }
    }

    var currentOverlay: some View {
        RoundedRectangle(cornerRadius: iconRadius + 3)
            .stroke(.primary, lineWidth: strokeWidth)
    }

    var lockOverlay: some View {
        Image(systemName: "lock")
            .symbolVariant(.circle.fill)
            .foregroundStyle(.white, settings.theme.tint)
            .imageScale(.large)
            .background(Circle().fill(.systemBackground))
            .offset(x: 3, y: -6)
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
        case .loading: break
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
