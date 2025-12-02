import SwiftUI

struct CustomFormats: View {
    var formats: [String]

    init(_ formats: [String]) {
        self.formats = formats
    }

    init(_ formats: [MediaCustomFormat]) {
        self.formats = formats.map { $0.label }
    }

    var body: some View {
        if !formats.isEmpty {
            OverflowLayout {
                ForEach(formats, id: \.self) { tag in
                    CustomFormat(tag)
                }
            }
        }
    }
}

struct CustomFormat: View {
    var label: String
    var style: CustomFormatStyle

    init(_ label: String, style: CustomFormatStyle = .secondary) {
        self.label = label
        self.style = style
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(colorScheme == .dark ? .lightText : .darkGray)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4).fill(.card)
            )
    }
}

enum CustomFormatStyle {
    case primary
    case secondary
}

struct OverflowLayout: Layout {
    var spacing = CGFloat(6)

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.replacingUnspecifiedDimensions().width
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        return layout(sizes: sizes, containerWidth: containerWidth).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets

        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: offset.x + bounds.minX, y: offset.y + bounds.minY), proposal: .unspecified)
        }
    }

    func layout(sizes: [CGSize], containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var result: [CGPoint] = []
        var currentPosition: CGPoint = .zero
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for size in sizes {
            if currentPosition.x + size.width > containerWidth {
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }

            result.append(currentPosition)
            currentPosition.x += size.width
            maxX = max(maxX, currentPosition.x)
            currentPosition.x += spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (result, CGSize(width: maxX, height: currentPosition.y + lineHeight))
    }
}

#Preview {
    Group {
        CustomFormats(["Test Foo, BAZ", "Test"])
    }
}
