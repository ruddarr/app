import SwiftUI

struct ShowsView: View {
    var body: some View {
        Text("TV Shows")
    }
}

#Preview {
    dependencies.router.selectedTab = .shows

    return ContentView()
        .withAppState()
}
