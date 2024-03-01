import SwiftUI

struct IconsView: View {
    @EnvironmentObject var settings: AppSettings

    let iconSize: CGFloat = 72
    var iconRadius: CGFloat { (10 / 57) * iconSize }

    let columns = [GridItem(.adaptive(minimum: 100, maximum: 120))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 15) {
                ForEach(AppIcon.allCases) { icon in
                    VStack {
                        let strokeWidth: CGFloat = 2

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
                                settings.icon = icon
                                UIApplication.shared.setAlternateIconName(icon.data.value)
                            }

                        Text(icon.data.label)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.top)
            .viewPadding(.horizontal)
        }
        .navigationTitle("Icons")
        .navigationBarTitleDisplayMode(.inline)
        .background(.secondarySystemBackground)

        Spacer()
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
