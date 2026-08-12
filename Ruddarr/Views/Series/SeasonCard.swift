import SwiftUI

struct SeasonCard: View {
    @Binding var series: Series
    var season: Season
    var status: QueueItemStatus?

    @State private var isWorking: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        LabeledGroupBox {
            HStack(spacing: 12) {
                Text(season.label)
                    .fontWeight(.medium)

                if let progress = season.progressLabel {
                    Text(progress)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let status {
                    QueueStatusIcon(status: status, color: colorScheme == .dark ? .lightGray : .darkGray)
                }

                Button {
                    Task {
                        await toggle()
                    }
                } label: {
                    RowMonitorButton(
                        monitored: seasonMonitored,
                        loading: isWorking
                    )
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!instance.series.isWorking)
                .disabled(!series.monitored)
            }
        }
    }

    private var seasonMonitored: Bool {
        series.seasons.first(where: { $0.id == season.id })?.monitored ?? season.monitored
    }

    func toggle() async {
        guard series.monitored else {
            return
        }

        guard let index = series.seasons.firstIndex(where: { $0.id == season.id }) else {
            return
        }

        let original = series.seasons[index].monitored
        series.seasons[index].monitored = !original

        isWorking = true

        guard await instance.series.push(series) else {
            series.seasons.revert(\.monitored, to: original, id: season.id)
            isWorking = false

            return
        }

        isWorking = false

        dependencies.toast.show(!original ? .monitored : .unmonitored)

        await instance.episodes.fetch(series)
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0] // 15
    let binding = Binding<Series>(get: { item }, set: { _ in })

    VStack {
        Section {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(item.seasons.reversed()) { season in
                    SeasonCard(series: binding, season: season)
                }
            }
        } header: {
            Text("Seasons")
                .font(.title2.bold())
                .padding(.bottom, 6)
        }
        .padding(.horizontal)
    }
    .withSonarrInstance(series: series)
    .withAppState()
}
