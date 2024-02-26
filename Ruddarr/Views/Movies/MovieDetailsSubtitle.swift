import SwiftUI

struct MovieDetailsSubtitle: View {
    var movie: Movie

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(String(movie.year))

                if let runtime = movie.runtimeLabel {
                    Text("•")
                    Text(runtime)
                }

                if movie.certification != nil {
                    Text("•")
                    Text(movie.certification ?? "")
                }
            }

            HStack(spacing: 6) {
                Text(String(movie.year))

                if let runtime = movie.runtimeLabel {
                    Text("•")
                    Text(runtime)
                }
            }
        }
        .font(.callout)
        .padding(.bottom, 6)
        .foregroundStyle(.secondary)
    }
}
