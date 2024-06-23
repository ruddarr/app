import SwiftUI

struct MovieListItem: View {
    var movie: Movie
    
    @Environment(RadarrInstance.self) private var instance
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            poster
                .frame(height: ListItemHelper.posterHeight())
                .contextMenu {
                    MovieContextMenu(movie: movie)
                } preview: {
                    poster.frame(width: 300)
                }
                .background(.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: ListItemHelper.posterRadius))
            
            VStack(alignment: .leading, spacing: 0) {
                Text(movie.title)
                    .font(ListItemHelper.primaryTextStyle())
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                HStack(spacing: ListItemHelper.listItemSpacing() / 2) {
                    Text(movie.yearLabel)
                    if movie.certificationLabel != String(localized: "Unrated") {
                        Text(movie.certificationLabel)
                    }
                    if let runtimeLabel = movie.runtimeLabel {
                        Text(runtimeLabel)
                    }
                }
                .lineLimit(1)
                .padding(.top, 2)
                .font(ListItemHelper.secondaryTextStyle())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .opacity(0.8)
                
                Text(movie.genreLabel)
                    .lineLimit(1)
                    .padding(.top, 2)
                    .font(ListItemHelper.tertiaryTextStyle())
                    .foregroundStyle(.secondary)
                    .opacity(0.8)
                
                VStack(alignment: .leading, spacing: 3) {
                    if movie.ratingsExist {
                        MovieRatings(movie: movie)
                            .padding(.leading, 1)
                            .font(ListItemHelper.secondaryTextStyle())
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: ListItemHelper.listItemSpacing() / 2) {
                        Image(systemName: "bookmark").symbolVariant(movie.monitored ? .fill : .none).tag()
                        Text(qualityProfileLabel(movie, instance)).tag()
                        if (!movie.sizeLabel.isEmpty) {
                            Text(movie.sizeLabel).tag()
                        }
                    }
                    .lineLimit(1)
                    .font(ListItemHelper.secondaryTextStyle())
                    .foregroundStyle(.secondary)
                }
                .padding(.top, ListItemHelper.listItemSpacing())
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, ListItemHelper.listItemSpacing() / 3)
            .padding(.bottom, ListItemHelper.listItemSpacing() / 2)
            .padding(.horizontal, ListItemHelper.listItemSpacing())
            .frame(height: ListItemHelper.posterHeight(), alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.foreground.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: ListItemHelper.posterRadius))
    }

    var poster: some View {
        CachedAsyncImage(.poster, movie.remotePoster, placeholder: movie.title)
            .clipShape(RoundedRectangle(cornerRadius: ListItemHelper.posterRadius))
            .aspectRatio(2/3, contentMode: .fit)
    }
    
    func qualityProfileLabel(_ movie: Movie, _ instance: RadarrInstance) -> String {
        instance.qualityProfiles.first(where: { $0.id == movie.qualityProfileId })?.name ?? String(localized: "Unknown")
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
        .sorted { $0.year > $1.year }
    
    return ScrollView {
        LazyVStack(spacing: ListItemHelper.listItemSpacing()) {
            ForEach(movies) { movie in
                MovieListItem(movie: movie)
            }
        }
        .padding(.top, 0)
        .viewPadding(.horizontal)
    }
    .withAppState()
}
