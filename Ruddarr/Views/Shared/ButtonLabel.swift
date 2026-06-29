import SwiftUI

struct ButtonLabel: View {
    enum Size {
        case regular, small
    }

    #if os(macOS)
        static let circleSize: CGFloat = 34
    #else
        static let circleSize: CGFloat = 44
    #endif

    private var label: Text?
    private var icon: String?
    private var size: Size = .regular
    private var isLoading: Bool = false
    private var prominent: Bool = false

    @ScaledMetric(relativeTo: .title3) private var regularIconHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote) private var smallIconHeight: CGFloat = 13

    init(text: String, icon: String? = nil, size: Size = .regular, prominent: Bool = false, isLoading: Bool = false) {
        self.label = Text(text)
        self.icon = icon
        self.size = size
        self.prominent = prominent
        self.isLoading = isLoading
    }

    init(text: LocalizedStringKey, icon: String? = nil, size: Size = .regular, prominent: Bool = false, isLoading: Bool = false) {
        self.label = Text(text)
        self.icon = icon
        self.size = size
        self.prominent = prominent
        self.isLoading = isLoading
    }

    init(icon: String, size: Size = .regular, prominent: Bool = false, isLoading: Bool = false) {
        self.icon = icon
        self.size = size
        self.prominent = prominent
        self.isLoading = isLoading
    }

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Label {
            if let label {
                label
                    .font(size == .small ? .caption : .callout)
                    .minimumScaleFactor(0.75)
            }
        } icon: {
            if let icon {
                Image(systemName: icon)
                    .font(iconFont)
                    .fontWeight(.medium)
                    .frame(height: label == nil ? nil : (size == .small ? smallIconHeight : regularIconHeight))
            }
        }
        .lineLimit(1)
        .opacity(isLoading ? 0 : 1)
        .overlay {
            if isLoading {
                ButtonProgressView(tint: prominent ? .white : nil)
            }
        }
        .fontWeight(.semibold)
        .foregroundStyle(prominent ? Color.white : settings.theme.tint)
        .padding(.horizontal, size == .small ? 2 : 4)
        .padding(.vertical, size == .small ? 3 : 5)
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.2), value: isLoading)
    }

    private var iconFont: Font {
        let iconOnly = label == nil
        switch size {
        case .small: return iconOnly ? .system(size: 14) : .footnote
        case .regular: return iconOnly ? .title2 : .title3
        }
    }
}

extension View {
    func actionButton() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.buttonFill)
    }

    func prominentActionButton(_ tint: Color) -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(tint)
    }

    func circularActionButton(size: CGFloat = ButtonLabel.circleSize) -> some View {
        buttonStyle(CircleActionButtonStyle(size: size))
    }

    func actionButtonWidth() -> some View {
        modifier(ActionButtonWidth())
    }
}

struct ActionButtonSpacer: View {
    @Environment(\.deviceType) private var deviceType

    @ViewBuilder
    var body: some View {
        if deviceType == .phone {
            Color.clear.frame(maxWidth: .infinity)
        }
    }
}

struct ButtonProgressView: View {
    var tint: Color?

    var body: some View {
        ProgressView()
            .tint(tint)
            #if os(macOS)
                .controlSize(.small)
            #endif
    }
}

private struct ActionButtonWidth: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    @ViewBuilder
    func body(content: Content) -> some View {
        if deviceType == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content
                .frame(minWidth: deviceType == .mac ? 150 : 175)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct CircleActionButtonStyle: ButtonStyle {
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(.buttonFill, in: Circle())
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

struct MacMenuButtonLabelModifier: ViewModifier {
    @Environment(\.deviceType) private var deviceType

    func body(content: Content) -> some View {
        #if os(macOS)
            content
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.tertiarySystemFill)
                )
        #else
            content
        #endif
    }
}

// swiftlint:disable closure_body_length
#Preview {
    @Previewable @State var isLoading: Bool = false

    let icons = [
        "arrow.up.forward",
        "arrow.up.forward.app",
        "arrow.down.app",
        "arrow.down.to.line",
        "bookmark",
        "trash"
    ]

    VStack(spacing: 20) {
        Button {
            isLoading.toggle()
        } label: {
            ButtonLabel(text: "Download", icon: "arrow.down.circle", isLoading: isLoading)
        }
        .buttonStyle(.glass)
        .fixedSize(horizontal: true, vertical: false)

        Button { } label: {
            ButtonLabel(text: "Manual Import", icon: "arrow.down.to.line", prominent: true)
        }
        .prominentActionButton(.purple)
        .fixedSize(horizontal: true, vertical: false)

        HStack(spacing: 16) {
            Button { } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
            }
            .actionButton()
            .actionButtonWidth()

            Button { } label: {
                ButtonLabel(text: "Interactive", icon: "person.fill")
            }
            .actionButton()
            .actionButtonWidth()
        }

        HStack(spacing: 16) {
            Button { } label: {
                ButtonLabel(text: "Interactive Search", icon: "person.fill")
            }
            .actionButton()
            .actionButtonWidth()

            Button {
                isLoading.toggle()
            } label: {
                ButtonLabel(icon: "magnifyingglass", isLoading: isLoading)
            }
            .circularActionButton()
        }

        HStack(spacing: 10) {
            Button { } label: {
                ButtonLabel(text: "2h 11m", icon: "play.fill", size: .small)
            }
            .actionButton()
            .fixedSize()

            Button { } label: {
                ButtonLabel(text: "Load More", size: .small)
            }
            .actionButton()
            .fixedSize()
        }

        HStack(spacing: 10) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    isLoading.toggle()
                } label: {
                    ButtonLabel(icon: icon, isLoading: isLoading)
                }
                .circularActionButton()
            }
        }
    }
    .padding()
    .withAppState()
    .macPreviewFrame()
}
// swiftlint:enable closure_body_length
