import SwiftUI
import AVFoundation

struct SearchingIndicator: View {
    @State private var opacity: Double = 0
    @State private var message: String = String(localized: "Hold on, this may take a moment.")
    @State private var player: AVAudioPlayer?

    let messages: [String] = [
        String(localized: "Still searching for releases."),
        // String(localized: "Try removing some slow trackers."),

        String(localized: "At least you're not on hold."),
        String(localized: "Let's hope it's worth the wait."),
        String(localized: "Discovering new ways of making you wait."),
        String(localized: "Just testing your patience."),
        String(localized: "Time flies when you're having fun."),
        String(localized: "Is this running on Windows?"),
        String(localized: "Try holding your breath."),
    ]

    var body: some View {
        ProgressView {
            VStack {
                Text("Searching...")
                Text(message)
                    .font(.footnote)
                    .opacity(opacity)
                    .animation(.smooth, value: message)
                    .animation(.smooth, value: opacity)
            }
        }
        .tint(.secondary)
        .onAppear {
            delayed(3, { opacity = 1 })
            delayed(10, { message = messages[0] })

            let delays = Array(stride(from: 20, through: messages.count * 10, by: 10))

            let randomMessages = messages.dropFirst().shuffled()

            for (index, delay) in delays.enumerated() {
                delayed(delay, {
                    message = randomMessages[index]

                    if Int.random(in: 1...100) <= 20 {
                        playAudio()
                    }
                })
            }
        }
        .onDisappear {
            stopAudio()
        }
        .onTapGesture {
            stopAudio()
        }
    }

    private func delayed(_ seconds: Int, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(seconds)) {
            action()
        }
    }

    private func playAudio() {
        guard player == nil else {
            return
        }

        guard let sound = Bundle.main.url(forResource: "elevator", withExtension: "mp3") else {
            return
        }

        player = try? AVAudioPlayer(contentsOf: sound)

        if let player {
            player.volume = 0.25
            player.play()
        }
    }

    private func stopAudio() {
        if let player {
            player.stop()
        }
    }
}

#Preview {
    SearchingIndicator()
}
