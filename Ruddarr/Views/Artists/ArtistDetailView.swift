import SwiftUI

struct ArtistDetailView: View {
    @Binding var artist: Artist

    @EnvironmentObject var settings: AppSettings

    @Environment(\.deviceType) private var deviceType
    @Environment(LidarrInstance.self) private var instance

    @State private var showEditForm = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Divider()
    }
}
