import SwiftUI

struct ShowsView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "tv.slash",
            description: Text("TV Series will be added once the movies component has been thoroughly tested in TestFlight.")
        )
    }
}

#Preview {
    dependencies.router.selectedTab = .shows

    return ContentView()
        .withAppState()
}
