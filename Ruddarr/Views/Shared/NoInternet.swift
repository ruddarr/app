import SwiftUI

struct NoInternet: View {
    var body: some View {
        ContentUnavailableView(
            "No Internet Connection",
            systemImage: "wifi.slash",
            description: Text("Please check your internet connection and try again.")
        )
    }
}

#Preview {
    NoInternet()
}
