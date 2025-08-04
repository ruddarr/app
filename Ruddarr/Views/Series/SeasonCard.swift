import SwiftUI

struct SeasonCard: View {
    @Binding var series: Series
    var season: Season

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

                Button {
                    Task {
                        await toggle()
                    }
                } label: {
                    if isWorking {
                        ProgressView().tint(.secondary).offset(x: 1.5)
                    } else {
                        Image(systemName: "bookmark")
                            .symbolVariant(season.monitored ? .fill : .none)
                            .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
                    }
                }
                .buttonStyle(.plain)
                .overlay(Rectangle().padding(18))
                .allowsHitTesting(!instance.series.isWorking)
            }
        }
    }

    func toggle() async {
        guard series.monitored else {
            return
        }

        guard let index = series.seasons.firstIndex(where: { $0.id == season.id }) else {
            return
        }

        series.seasons[index].monitored.toggle()

        isWorking = true

        guard await instance.series.push(series) else {
            isWorking = false
            return
        }

        isWorking = false

        dependencies.toast.show(
            series.seasons[index].monitored ? .monitored : .unmonitored
        )

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
