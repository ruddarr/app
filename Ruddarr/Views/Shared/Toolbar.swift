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
    var loading: Bool = false

    @State private var pulsing = false

    var body: some View {
        Image(systemName: "bookmark")
            .symbolVariant(monitored ? .fill : .none)
            .symbolEffect(.pulse, isActive: pulsing)
            .animation(.snappy, value: monitored)
            .font(.subheadline)
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

        VStack(spacing: 12) {
            Button("Toggle Monitored") { monitored.toggle() }
            Button(loading ? "Stop Loading" : "Start Loading") { loading.toggle() }
        }
        .buttonStyle(.bordered)
    }
    .padding(40)
}
