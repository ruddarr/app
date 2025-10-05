import SwiftUI
import Combine
import AVFoundation

struct SearchingIndicator: View {
    @State private var messages: [String] = [
        String(localized: "At least you're not on hold.", comment: "Release search taunt"),
        String(localized: "Let's hope it's worth the wait.", comment: "Release search taunt"),
        String(localized: "Discovering new ways of making you wait.", comment: "Release search taunt"),
        String(localized: "Just testing your patience.", comment: "Release search taunt"),
        String(localized: "Time flies when you're having fun.", comment: "Release search taunt"),
        String(localized: "Is this running on Windows?", comment: "Release search taunt"),
        String(localized: "Try holding your breath.", comment: "Release search taunt"),
    ]

    @State private var opacity: Double = 0
    @State private var message: String = " "

    @State private var player: AVAudioPlayer?
    @State private var seconds: Int = 0
    @State private var audioTimer: Timer?

    @AppStorage("elevator", store: dependencies.store) var elevator: Bool = true

    private let textTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onReceive(textTimer, perform: tick)
        .onDisappear {
            stopAudio()
            textTimer.upstream.connect().cancel()
        }
        .gesture(
            TapGesture(count: 3).onEnded {
                elevator = false
                stopAudio()
            }.exclusively(before: TapGesture(count: 1).onEnded {
                stopAudio()
            })
        )
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

                if Int.random(in: 1...100) <= 20 {
                    playAudio()
                }
            }
        default:
            break
        }
    }

    private func playAudio() {
        guard elevator else {
            return
        }

        guard player == nil else {
            return
        }

        guard let sound = Bundle.main.url(forResource: "elevator", withExtension: "mp3") else {
            return
        }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        player = try? AVAudioPlayer(contentsOf: sound)
        player?.volume = 0
        player?.play()

        fadeVolume(to: 0.25)
    }

    private func stopAudio() {
        fadeVolume(to: 0)
    }

    @MainActor
    private func fadeVolume(to endVolume: Float) {
        audioTimer?.invalidate()

        let startVolume = player?.volume ?? 0
        let duration: TimeInterval = 2
        let interval: TimeInterval = 0.1
        let steps = duration / interval
        let volumeStep = (endVolume - startVolume) / Float(steps)

        audioTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                let currentVolume = player?.volume ?? 0
                let newVolume = currentVolume + volumeStep

                if (volumeStep > 0 && newVolume >= endVolume) || (volumeStep < 0 && newVolume <= endVolume) {
                    player?.volume = endVolume

                    if endVolume == 0 {
                        player?.stop()

                        #if os(iOS)
                        try? AVAudioSession.sharedInstance().setActive(false)
                        #endif
                    }

                    audioTimer?.invalidate()
                } else {
                    player?.volume = newVolume
                }
            }
        }
    }
}

#Preview {
    List {
        //
    }
    .overlay {
        SearchingIndicator()
    }
}
