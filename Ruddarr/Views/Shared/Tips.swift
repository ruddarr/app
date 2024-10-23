import TipKit

struct SeriesMonitoringTip: Tip {
    @Parameter static var monitored: Bool = true

    init(_ monitored: Bool) {
        Self.monitored = monitored
    }

    var title: Text {
        Text("Series Not Monitored")
    }

    var message: Text? {
        Text("To monitor a season or episode, the series itself must be monitored.")
    }

    var rules: [Rule] {
        #Rule(Self.$monitored) {
            $0 == false
        }
    }
}

struct DeleteFileTip: Tip {
    var title: Text {
        Text("Deleting Files")
    }

    var message: Text? {
        Text("Long-press any file to delete it.")
    }
}

struct NoAutomaticSearchTip: Tip {
    static let mediaAdded = Event(id: "mediaAdded")

    var title: Text {
        Text("No Automatic Search")
    }

    var message: Text? {
        Text("Ruddarr does not start an automatic search when adding media, but you can.")
    }

    var rules: [Rule] {
        #Rule(Self.mediaAdded) {
            $0.donations.count > 0
        }
    }
}
