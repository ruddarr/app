import SwiftUI

struct ShowsView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "tv.slash",
            description: Text("TV Shows will be added in a few weeks, once the Movies module has been polished and thoroughly tested in TestFlight.")
        )
    }
}

#Preview {
    dependencies.router.selectedTab = .shows

    return ContentView()
        .withAppState()
}
