import SwiftUI

struct WhatsNew {
    static func markAsPresented() {
        dependencies.store.set(bundleBuild(), forKey: "whatsnew:\(version)")
    }

    static func shouldPresent() -> Bool {
        guard version == bundleVersion() else {
            return false
        }

        guard let presented = dependencies.store.string(forKey: "whatsnew:\(version)") else {
            return true
        }

        return presented != bundleBuild()
    }

    static func bundleVersion() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    static func bundleBuild() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 60) {
                    title

                    VStack(alignment: .leading, spacing: 25) {
                        ForEach(WhatsNew.features, id: \.title, content: feature)
                    }
                    .modifier(WhatsNewFeaturesPadding())
                    .padding(.leading, 15)
                }
                .padding(.horizontal)
                .padding(.top, 65)

                Color.clear.padding(.bottom, 150)
            }

            VStack {
                Spacer()

                footer
                    .modifier(WhatsNewFooterPadding())
                    .background(.white)
            }
            .edgesIgnoringSafeArea(.bottom)

        }
        .onDisappear {
            WhatsNew.markAsPresented()
        }
    }

    var title: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .phone {
                VStack {
                    Text(verbatim: "What's New in")
                    Text(verbatim: "Ruddarr").foregroundStyle(.blue)
                }
            } else {
                Group {
                    Text(verbatim: "What's New in ") +
                    Text(verbatim: "Ruddarr").foregroundStyle(.blue)
                }
            }
        }
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
    }

    var footer: some View {
        VStack(spacing: 15) {
            HStack {
                Spacer()

                Button("Continue") {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
                    .font(.headline.weight(.semibold))
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer()
            }
        }
    }

    func feature(_ feature: WhatsNewFeature) -> some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: feature.image)
                .font(.title)
                .imageScale(.large)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct WhatsNewFeature {
    var image: String
    var title: String
    var subtitle: String
}

struct WhatsNewFooterPadding: ViewModifier {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    func body(content: Content) -> some View {
        if self.horizontalSizeClass == .regular {
            content.padding(
                .init(top: 0, leading: 150, bottom: 50, trailing: 150)
            )
        } else if self.verticalSizeClass == .compact {
            content.padding(
                .init(top: 0, leading: 40, bottom: 35, trailing: 40)
            )
        } else {
            content.padding(
                .init(top: 0, leading: 20, bottom: 80, trailing: 20)
            )
        }
    }
}

struct WhatsNewFeaturesPadding: ViewModifier {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    func body(content: Content) -> some View {
        if self.horizontalSizeClass == .regular {
            content.padding(
                .init(top: 0, leading: 100, bottom: 0, trailing: 100)
            )
        } else {
            content
        }
    }
}

extension View {
    func whatsNewSheet() -> some View {
        self.modifier(WhatsNewSheetViewModifier())
    }
}

private struct WhatsNewSheetViewModifier: ViewModifier {
    @State private var isPresented: Bool = true

    func body(content: Content) -> some View {
        if WhatsNew.shouldPresent() {
            content.sheet(isPresented: $isPresented) {
                WhatsNewView()
            }
        } else {
            content
        }
    }
}

#Preview {
    @State var show: Bool = true

    return NavigationView { }.sheet(isPresented: $show, content: {
        WhatsNewView()
    })
}
