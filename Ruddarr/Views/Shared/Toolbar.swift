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

struct MonitorBookmark: View {
    @Binding var monitored: Bool
    var loading: Bool = false

    @State private var pulsing = false

    var body: some View {
        Image(systemName: "bookmark")
            .symbolVariant(monitored ? .fill : .none)
            .symbolEffect(.pulse, isActive: pulsing)
            .animation(.snappy, value: monitored)
            .task(id: loading) {
                guard loading else {
                    pulsing = false
                    return
                }

                try? await Task.sleep(for: .milliseconds(200))

                if !Task.isCancelled {
                    pulsing = true
                }
            }
    }
}

struct ToolbarMonitorButton: View {
    @Binding var monitored: Bool
    var loading: Bool = false

    var body: some View {
        MonitorBookmark(monitored: $monitored, loading: loading)
            .font(.subheadline)
            .tint(.primary)
    }
}

struct RowMonitorButton: View {
    @Binding var monitored: Bool
    var loading: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MonitorBookmark(monitored: $monitored, loading: loading)
            .font(.body)
            .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
            .overlay(Rectangle().padding(18))
    }
}

struct ToolbarActionButton: View {
    var body: some View {
        Image(systemName: "ellipsis")
    }
}

#Preview {
    @Previewable @State var monitored = true
    @Previewable @State var loading = false

    VStack(spacing: 32) {
        ToolbarMonitorButton(monitored: $monitored, loading: loading)
        RowMonitorButton(monitored: $monitored, loading: loading)

        VStack(spacing: 12) {
            Button("Toggle Monitored") { monitored.toggle() }
            Button(loading ? "Stop Loading" : "Start Loading") { loading.toggle() }
        }
        .buttonStyle(.bordered)
    }
    .padding(40)
}
