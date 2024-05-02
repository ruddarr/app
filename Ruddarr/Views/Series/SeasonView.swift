import SwiftUI

struct SeasonView: View {
    @Binding var series: Series
    var seasonId: Season.ID

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        HStack {
            Text(series.title)
            Text(String(season.seasonNumber))
        }
    }

    var season: Season {
        series.seasonById(seasonId)!
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 2 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesView.Path.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesView.Path.season(item.id, 1)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
