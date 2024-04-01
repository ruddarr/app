import SwiftUI

struct SeriesView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Coming Soon", systemImage: "tv.slash")
        } description: {
            Text("TV Series will be added once the movies component has been thoroughly tested in TestFlight.")
        } actions: {
            Link(destination: Links.Discord) {
                Text(verbatim: "Join the Discord")
            }
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .series

    return ContentView()
        .withAppState()
}
