import SwiftUI

struct NoInternet: View {
    static var Title = String(localized: "No Internet Connection")
    static var Description = String(localized: "Please check your internet connection and try again.")
    // The Internet connection appears to be offline.

    var body: some View {
        ContentUnavailableView(
            NoInternet.Title,
            systemImage: "wifi.slash",
            description: Text(NoInternet.Description)
        )
    }
}

#Preview {
    NoInternet()
}
