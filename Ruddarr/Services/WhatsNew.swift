import SwiftUI

struct WhatsNew {
    static func markAsPresented() {
        dependencies.store.set(bundleBuild(), forKey: "whatsnew:\(version)")
    }

    static func shouldPresent() -> Bool {
        guard !WhatsNew.features.isEmpty else {
            return false
        }

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
    @Environment(\.deviceType) private var deviceType

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
                    #if os(iOS)
                        .background(.systemBackground)
                    #endif
            }
            .edgesIgnoringSafeArea(.bottom)

        }
        .onDisappear {
            WhatsNew.markAsPresented()
        }
    }

    var title: some View {
        let appName = Text(verbatim: Ruddarr.name).foregroundStyle(.tint)

        return Text("What's New in \(appName)")
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
    }

    var footer: some View {
        VStack(spacing: 15) {
            HStack {
                Spacer()

                VStack {
                    if isRunningIn(.appstore) {
                        Link(destination: Links.AppStore) {
                            Text(verbatim: "Release Notes")
                        }
                        .foregroundStyle(.tint)
                        .padding(.bottom, 10)
                    }

                    Button {
                        #if os(iOS)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif

                        dismiss()
                    } label: {
                        Text(verbatim: "Continue")
                            .font(.headline.weight(.semibold))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }

                Spacer()
            }
        }
    }

    func feature(_ feature: WhatsNewFeature) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: feature.image)
                .font(.title)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .frame(width: 40)
                #if os(iOS)
                    .offset(y: deviceType == .phone ? 10 : 5)
                #endif

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        #if os(macOS)
            content.padding(
                .init(top: 0, leading: 30, bottom: 30, trailing: 30)
            )
        #else
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
        #endif
    }
}

struct WhatsNewFeaturesPadding: ViewModifier {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    func body(content: Content) -> some View {
        #if os(macOS)
            content.padding(.horizontal)
        #else
            if self.horizontalSizeClass == .regular {
                content.padding(
                    .init(top: 0, leading: 100, bottom: 0, trailing: 100)
                )
            } else {
                content
            }
        #endif
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
    @Previewable @State var show: Bool = true

    return NavigationView {
        Text(verbatim: "Cupidatat adipisicing elit dolor cillum.")
    }.sheet(isPresented: $show, content: {
        WhatsNewView()
            // .environment(\.sizeCategory, .extraExtraLarge)
    })
}
