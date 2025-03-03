import SwiftUI
import Combine
import AVFoundation

struct SearchingIndicator: View {
    @State private var messages: [String] = [
        String(localized: "At least you're not on hold."),
        String(localized: "Let's hope it's worth the wait."),
        String(localized: "Discovering new ways of making you wait."),
        String(localized: "Just testing your patience."),
        String(localized: "Time flies when you're having fun."),
        String(localized: "Is this running on Windows?"),
        String(localized: "Try holding your breath."),
    ]

    @State private var opacity: Double = 0
    @State private var message: String = " "

    @State private var player: AVAudioPlayer?
    @State private var seconds: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .onReceive(timer, perform: tick)
        .onDisappear {
            stopAudio()
            timer.upstream.connect().cancel()
        }
        .onTapGesture {
            stopAudio()
        }
    }

    private func tick(_ date: Date) {
        seconds += 1

        switch seconds {
        case 3:
            message = String(localized: "Hold on, this may take a moment.")
            opacity = 1
        case 10:
            message = String(localized: "Still searching for releases.")
        case let seconds where seconds >= 20 && seconds % 10 == 0:
            messages.shuffle()

            if let last = messages.popLast() {
                message = last
                guard Int.random(in: 1...100) <= 20 else { break }
                playAudio()
            }
        default:
            break
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
        player?.volume = 0.25
        player?.play()
    }

    private func stopAudio() {
        player?.stop()
    }
}

#Preview {
    SearchingIndicator()
}
