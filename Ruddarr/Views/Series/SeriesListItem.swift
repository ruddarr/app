import SwiftUI

struct SeriesListItem: View {
    var series: Series
    
    @Environment(SonarrInstance.self) private var instance
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            poster
                .frame(height: ListItemHelper.posterHeight())
                .contextMenu {
                    SeriesContextMenu(series: series)
                } preview: {
                    poster.frame(width: 300, height: 450)
                }
                .background(.secondarySystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: ListItemHelper.posterRadius))
            
            VStack(alignment: .leading, spacing: 0) {
                Text(series.title)
                    .font(ListItemHelper.primaryTextStyle())
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                HStack(spacing: ListItemHelper.listItemSpacing() / 2) {
                    Text(series.yearLabel)
                    if series.certificationLabel != String(localized: "Unrated") {
                        Text(series.certificationLabel)
                    }
                    Text("\(series.seasonCount) Seasons")
                }
                .lineLimit(1)
                .padding(.top, 2)
                .font(ListItemHelper.secondaryTextStyle())
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .opacity(0.8)
                
                Text(series.genreLabel)
                    .lineLimit(1)
                    .padding(.top, 2)
                    .font(ListItemHelper.tertiaryTextStyle())
                    .foregroundStyle(.secondary)
                    .opacity(0.8)
                
                VStack(alignment: .leading, spacing: 3) {
                    Group {
                        if nextAiringLabel != "" && series.network != nil {
                            Text("\(nextAiringLabel) on \(series.network ?? "")")
                        } else if nextAiringLabel != "" {
                            Text(nextAiringLabel)
                        } else if let network = series.network {
                            Text(network)
                        }
                    }
                    .lineLimit(1)
                    .font(ListItemHelper.secondaryTextStyle())
                    .foregroundStyle(.secondary)
                        
                    HStack(spacing: ListItemHelper.listItemSpacing() / 2) {
                        Image(systemName: "bookmark").symbolVariant(series.monitored ? .fill : .none).tag()
                        Text(qualityProfileLabel).tag()
                        if let sizeLabel = series.sizeLabel, !sizeLabel.isEmpty {
                            Text(sizeLabel).tag()
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
        CachedAsyncImage(.poster, series.remotePoster, placeholder: series.title)
            .clipShape(RoundedRectangle(cornerRadius: ListItemHelper.posterRadius))
            .aspectRatio(2/3, contentMode: .fit)
    }
    
    var qualityProfileLabel: String {
        instance.qualityProfiles.first(where: { $0.id == series.qualityProfileId })?.name ?? String(localized: "Unknown")
    }
    
    var nextAiringLabel: String {
        guard let date = series.nextAiring else { return "" }
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        let weekday = date.formatted(.dateTime.weekday(.wide))

        if calendar.isDateInToday(date) { return String(localized: "\(RelativeDate.today.label) at \(time)") }
        if calendar.isDateInTomorrow(date) { return String(localized: "\(RelativeDate.tomorrow.label) at \(time)") }

        guard let days = calendar.dateComponents([.day], from: Date.now, to: date).day else {
            return ""
        }

        return days < 7
            ? String(localized: "\(weekday) at \(time)")
            : date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
        .sorted { $0.year > $1.year }
    
    return ScrollView {
        LazyVStack(spacing: ListItemHelper.listItemSpacing()) {
            ForEach(series) { series in
                SeriesGridItem(series: series)
            }
        }
        .padding(.top, 0)
        .viewPadding(.horizontal)
    }
    .withAppState()
}
