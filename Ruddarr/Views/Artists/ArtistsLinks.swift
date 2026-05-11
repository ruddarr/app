import SwiftUI

struct ArtistLinks: View {
    var artist: Artist

    var body: some View {
        let links = artist.links.sorted { $0.name ?? "" < $1.name ?? "" }

        ForEach(links, id: \.url) { link in
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
