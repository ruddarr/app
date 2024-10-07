import TipKit

struct SeriesMonitoringTip: Tip {
    var title: Text {
        Text("Series Not Monitored")
    }

    var message: Text? {
        Text("The series itself must be monitored, in order to monitor a season or episode.")
    }
}
