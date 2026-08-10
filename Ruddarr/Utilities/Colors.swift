import SwiftUI

struct SheetBackgroundStyle: ShapeStyle {
    func resolve(in env: EnvironmentValues) -> some ShapeStyle {
        if env.colorScheme == .dark {
            AnyShapeStyle(.systemBackground)
        } else {
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

extension ShapeStyle where Self == SheetBackgroundStyle {
    static var sheetBackground: SheetBackgroundStyle { .init() }
}

extension ShapeStyle where Self == Color {
    static var systemPurple: Color { Color(red: 88 / 255, green: 86 / 255, blue: 215 / 255) }

#if os(iOS)
    static var card: Color { .quaternarySystemFill }
    static var elevatedCard: Color { .tertiarySystemFill }
    static var label: Color { Color(UIColor.label) }

    static var darkGray: Color { Color(UIColor.darkGray) }
    static var darkText: Color { Color(UIColor.darkText) }

    static var lightGray: Color { Color(UIColor.lightGray) }
    static var lightText: Color { Color(UIColor.lightText) }

    static var systemFill: Color { Color(UIColor.systemFill) }
    static var secondarySystemFill: Color { Color(UIColor.secondarySystemFill) }
    static var tertiarySystemFill: Color { Color(UIColor.tertiarySystemFill) }
    static var quaternarySystemFill: Color { Color(UIColor.quaternarySystemFill) }

    static var systemBackground: Color { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
    static var tertiarySystemBackground: Color { Color(UIColor.tertiarySystemBackground) }

    static var systemGroupedBackground: Color { Color(UIColor.systemGroupedBackground) }
    static var secondarySystemGroupedBackground: Color { Color(UIColor.secondarySystemGroupedBackground) }

    static var buttonFill: Color { Color(UIColor.systemGray5) }
#else
    static var card: Color { .tertiarySystemFill }
    static var elevatedCard: Color { .secondarySystemFill }
    static var label: Color { Color(NSColor.labelColor) }

    static var darkGray: Color { Color(NSColor.darkGray) }
    static var darkText: Color { Color(NSColor.secondaryLabelColor) }

    static var lightGray: Color { Color(NSColor.lightGray) }
    static var lightText: Color { Color(NSColor.secondaryLabelColor) }

    static var systemFill: Color { Color(NSColor.systemFill) }
    static var secondarySystemFill: Color { Color(NSColor.secondarySystemFill) }
    static var tertiarySystemFill: Color { Color(NSColor.tertiarySystemFill) }
    static var quaternarySystemFill: Color { Color(NSColor.quaternarySystemFill) }

    static var systemBackground: Color { Color(NSColor.windowBackgroundColor) }
    static var secondarySystemBackground: Color { Color(NSColor.controlBackgroundColor) }
    static var tertiarySystemBackground: Color { Color(NSColor.underPageBackgroundColor) }

    static var systemGroupedBackground: Color { Color(NSColor.windowBackgroundColor) }
    static var secondarySystemGroupedBackground: Color { Color(NSColor.controlBackgroundColor) }

    static var buttonFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 0.204, green: 0.196, blue: 0.224, alpha: 1)
                : NSColor(srgbRed: 0.898, green: 0.898, blue: 0.918, alpha: 1)
        })
    }
#endif
}
