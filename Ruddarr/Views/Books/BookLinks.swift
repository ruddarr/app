import SwiftUI

struct BookLinks: View {
    var book: Book

    var body: some View {
        ForEach(book.webLinks, id: \.self) { link in
            if let destination = link.destination, let label = link.label {
                Link(destination: destination, label: {
                    Label("Open in \(label)", systemImage: "arrow.up.forward.app")
                })
            }
        }
    }
}
