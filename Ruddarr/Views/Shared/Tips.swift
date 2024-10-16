import TipKit

struct SeriesMonitoringTip: Tip {
    var title: Text {
        Text("Series Not Monitored")
    }

    var message: Text? {
        Text("The series itself must be monitored, in order to monitor a season or episode.")
    }
}

struct DeleteFileTip: Tip {
    var title: Text {
        Text("Long tap to delete file")
    }

    var message: Text? {
        Text("Use long tap to delete file from the device.")
    }
}
