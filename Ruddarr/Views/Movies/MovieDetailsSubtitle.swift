import SwiftUI

struct MovieDetailsSubtitle: View {
    var movie: Movie

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(String(movie.year))
                Text("•")
                Text(movie.runtimeLabel)

                if movie.certification != nil {
                    Text("•")
                    Text(movie.certification ?? "")
                }
            }

            HStack(spacing: 6) {
                Text(String(movie.year))
                Text("•")
                Text(movie.runtimeLabel)
            }
        }
        .font(.callout)
        .padding(.bottom, 6)
        .foregroundStyle(.secondary)
    }
}
