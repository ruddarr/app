import SwiftUI

struct InstanceWebLink: View {
    var instance: Instance
    var path: String = ""

    @Environment(\.openURL) private var openURL

    var body: some View {
        #if os(iOS)
            Button("Open in \(instance.label)", systemImage: "safari") {
                Task {
                    if let url = await instance.webURL(path: path) {
                        openURL(url, prefersInApp: true)
                    }
                }
            }
        #endif
    }
}
