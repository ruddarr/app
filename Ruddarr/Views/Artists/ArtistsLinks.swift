import SwiftUI

struct ArtistsLinks: View {
    var artist: Artist

    var body: some View {
        ForEach(artist.links) { link in
            if let url = link.url, let name = link.name {
                Link(destination: URL(string: url)!, label: {
                    Label("Open in \(name)", systemImage: "arrow.up.right.square")
                })
            }
        }
    }

    func link(name: String, url: String) -> some View {
        Link(destination: URL(string: url)!, label: {
            Label("Open in \(name)", systemImage: "arrow.up.right.square")
        })
    }
}
