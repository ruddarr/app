import SwiftUI

struct EpisodeSheet: View {
    var series: Series
    var episode: Episode

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    let smallScreen = UIDevice.current.userInterfaceIdiom == .phone

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)
                        .padding(.trailing, 25)

//                    actions
//                        .padding(.bottom)
//
//                    details
//                        .padding(.bottom)
                }
                .padding(.top)
                .viewPadding(.horizontal)
            }
//            .alert(
//                isPresented: instance.movies.errorBinding,
//                error: instance.movies.error
//            ) { _ in
//                Button("OK") { instance.movies.error = nil }
//            } message: { error in
//                Text(error.recoverySuggestionFallback)
//            }
        }

        // season 2 * episode 1
        // file details (media etc.)
        // monitor button
        // search buttons
        // history
    }

    var header: some View {
        VStack(alignment: .leading) {
            Text(episode.statusLabel)
            .font(.footnote)
            .fontWeight(.semibold)
            .tracking(1.1)
            .foregroundStyle(settings.theme.tint)

            Text(episode.title ?? "TBA")
                .font(.title2)
                .fontWeight(.bold)
                .kerning(-0.5)

            HStack(spacing: 6) {
                if let airdate = episode.airDateUtc {
                    Text(airdate.formatted(date: .abbreviated, time: .omitted))
                    // Bullet()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if episode.overview != nil {
                description
                    .padding(.top, 6)
            }
        }
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(episode.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 3 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.35)) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = smallScreen
        }
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    let episodes: [Episode] = PreviewData.load(name: "series-episodes")

    return EpisodeSheet(series: item, episode: episodes[1])
        .withAppState()
}
