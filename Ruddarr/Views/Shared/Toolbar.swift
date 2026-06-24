import SwiftUI

struct Bullet: View {
    var body: some View {
        Text(verbatim: "•")
    }
}

struct ToolbarFilterBadge: View {
    var body: some View {
        Image(systemName: "circle")
            .symbolVariant(.fill)
            .foregroundStyle(.primary)
            .overlay {
                Circle().stroke(.systemBackground, lineWidth: 5)
            }
            .scaleEffect(0.35)
            .offset(x: 8, y: -7)
    }
}

struct ToolbarMonitorButton: View {
    @Binding var monitored: Bool

    var body: some View {
        Image(systemName: "bookmark")
            .symbolVariant(monitored ? .fill : .none)
            .font(.subheadline)
            .tint(.primary)
    }
}

struct ToolbarActionButton: View {
    var body: some View {
        Image(systemName: "ellipsis")
    }
}

extension View {
    /// Indicates an active toolbar filter using a prominent, tinted Liquid Glass
    /// background (iOS 26) instead of a custom badge glyph. Inactive buttons keep
    /// the standard toolbar glass styling.
    @ViewBuilder
    func toolbarFilterIndicator(active: Bool, tint: Color) -> some View {
        if active {
            self
                .menuStyle(.button)
                .buttonStyle(.glassProminent)
                .tint(tint)
        } else {
            self
        }
    }
}
