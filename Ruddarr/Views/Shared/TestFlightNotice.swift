import SwiftUI

extension View {
    func testFlightNotice() -> some View {
        modifier(TestFlightNoticeViewModifier())
    }
}

private struct TestFlightNoticeViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            TestFlightNoticeView()
        #else
            content
        #endif
    }
}

#if os(iOS)
struct TestFlightNoticeView: View {
    @Environment(\.openURL) private var openURL

    private let review = Links.AppStore.appending(queryItems: [
        .init(name: "action", value: "write-review"),
    ])

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    icon
                    title
                    subtitle
                    stars
                    message

                    Color.clear.padding(.bottom, 160)
                }
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 40)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .background(.systemBackground)

            VStack {
                Spacer()

                footer
                    .modifier(WhatsNewFooterPadding())
                    .background(.systemBackground)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }

    var icon: some View {
        Image("AppIconPreviewDefault")
            .resizable()
            .frame(width: 90, height: 90)
            .clipShape(.rect(cornerRadius: (15 / 57) * 90))
            .padding(.bottom, 8)
    }

    var title: some View {
        Text(verbatim: "Thanks for Testing \(Ruddarr.name) 2.0")
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    var subtitle: some View {
        Text(verbatim: "It's been released on the App Store.")
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    var stars: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
            Image(systemName: "star.fill")
            Image(systemName: "star.fill")
            Image(systemName: "star.fill")
            Image(systemName: "star.fill")
        }
        .font(.title2)
        .foregroundStyle(.tint)
        .padding(.top, 8)
        .accessibilityHidden(true)
    }

    var message: some View {
        Text(verbatim: "If you enjoy using \(Ruddarr.name) consider leaving a 5-star review, it means a lot to me.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    var footer: some View {
        VStack(spacing: 12) {
            Button {
                openURL(Links.AppStore)
            } label: {
                Text(verbatim: "\(Ruddarr.name) on the App Store")
                    .font(.headline.weight(.semibold))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
    }
}
#endif

#if os(iOS)
#Preview {
    TestFlightNoticeView()
        .withAppState()
}
#endif
