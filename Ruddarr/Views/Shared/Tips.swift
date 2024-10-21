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
        Text("Long tap to delete file")
    }

    var message: Text? {
        Text("Use long tap to delete file from the device.")
    }

    var options: [any Option] {
        [
            MaxDisplayCount(1)
        ]
    }
}
