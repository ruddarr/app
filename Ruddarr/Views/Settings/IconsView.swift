import SwiftUI

struct IconsView: View {

    let columns = [
        GridItem(.adaptive(minimum: 100)),
        GridItem(.adaptive(minimum: 100)),
    ]

    var body: some View {
        LazyVGrid(columns: columns) {

            let xxx = print(alternateIcons)

            ForEach(alternateIcons) { icon in
                if let image = icon.iconImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .padding()
                }
            }

            ForEach(1...20, id: \.self) { index in
                VStack {

                    Image(uiImage: UIImage(named: "IconDefault") ?? UIImage())

                    if let image = UIImage(named: "IconDefault") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

//                    Image("Icons/IconDefault")
//                        .resizable()
//                        .frame(width: 50, height: 50)
                    Text("Item \(index)")
                }
            }
        }
    }

    private func getAlternateAppIconNames() -> [String] {
        let appIconsDict: [String: [String: Any]] = getValue(for: "CFBundleIcons")

        let alternateIconsDict = appIconsDict["CFBundleAlternateIcons"] as? [String: [String: String]]

        var alternateAppIconNames = [String]()

        alternateIconsDict?.forEach { _, value in
            if let alternateIconName = value["CFBundleIconName"] {
                alternateAppIconNames.append(alternateIconName)
            }
        }

        return alternateAppIconNames
    }


    var alternateIcons: [AlternateIcon] {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any] else {
            return []
        }

        var iconList: [AlternateIcon] = []

        for (iconName, iconDetails) in alternateIcons {
            if let iconDetails = iconDetails as? [String: Any],
               let iconFiles = iconDetails["CFBundleIconFiles"] as? [String],
               let iconFileName = iconFiles.last,
               let iconImage = UIImage(named: iconFileName) {
                iconList.append(AlternateIcon(iconName: iconName, iconImage: iconImage))
            }
        }
        return iconList
    }

}

struct AlternateIcon: Identifiable {
    var id: String { iconName }
    let iconName: String
    let iconImage: UIImage?
}

#Preview {
    dependencies.router.selectedTab = .settings

    dependencies.router.settingsPath.append(
        SettingsView.Path.icons
    )

    return ContentView()
        .withAppState()
}
