import TipKit

struct SeriesMonitoringTip: Tip {
    @Parameter
    static var seriesMonitored: Bool = true

    init(_ seriesMonitored: Bool) {
        Self.seriesMonitored = seriesMonitored
    }

    var title: Text {
        Text("Series Not Monitored")
    }

    var message: Text? {
        Text("To monitor a season or episode, the series itself must be monitored.")
    }

    var rules: [Rule] {
        [
            #Rule(Self.$seriesMonitored) { $0 == false }
        ]
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
