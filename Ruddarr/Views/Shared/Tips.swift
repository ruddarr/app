import TipKit

struct SeriesMonitoringTip: Tip {
    @Parameter static var seriesMonitored: Bool = true

    var title: Text {
        Text("Series Not Monitored")
    }

    var message: Text? {
        Text("The series itself must be monitored, in order to monitor a season or episode.")
    }

    var rules: [Rule] {
        [
            #Rule(Self.$seriesMonitored) {
                $0 == false
            }
        ]
    }

    init(_ seriesMonitored: Bool) {
        Self.seriesMonitored = seriesMonitored
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
