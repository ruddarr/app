import SwiftUI

struct CustomFormats: View {
    var formats: [String]
    var small: Bool

    init(_ formats: [String], small: Bool = false) {
        self.formats = formats
        self.small = small
    }

    init(_ formats: [MediaCustomFormat]) {
        self.formats = formats.map(\.label)
        self.small = false
    }

    var body: some View {
        if !formats.isEmpty {
            OverflowLayout {
                ForEach(formats, id: \.self) { tag in
                    CustomFormat(tag, small: small)
                }
            }
        }
    }
}

struct CustomFormat: View {
    var label: String
    var style: CustomFormatStyle
    var small: Bool

    init(_ label: String, style: CustomFormatStyle = .secondary, small: Bool = false) {
        self.label = label
        self.style = style
        self.small = small
    }

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var smallSize: CGFloat = 10

    var body: some View {
        Text(label)
            .font(small ? .system(size: smallSize) : .caption2)
            .fontWeight(.semibold)
            .foregroundStyle(colorScheme == .dark ? .lightText : .darkGray)
            .padding(.vertical, small ? 3 : 4)
            .padding(.horizontal, small ? 6 : 8)
            .background(
                RoundedRectangle(cornerRadius: small ? 3.5 : 4).fill(.card)
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
        let sizes = subviewSizes(of: subviews, clampedTo: proposal.width)

        return layout(sizes: sizes, containerWidth: containerWidth).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviewSizes(of: subviews, clampedTo: proposal.width)
        let offsets = layout(sizes: sizes, containerWidth: bounds.width).offsets

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: offsets[index].x + bounds.minX, y: offsets[index].y + bounds.minY),
                proposal: ProposedViewSize(sizes[index])
            )
        }
    }

    func subviewSizes(of subviews: Subviews, clampedTo width: CGFloat?) -> [CGSize] {
        subviews.map { subview in
            let size = subview.sizeThatFits(.unspecified)

            guard let width, width > 0, size.width > width else {
                return size
            }

            return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
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
