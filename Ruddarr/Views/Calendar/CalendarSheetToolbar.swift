import SwiftUI

struct CalendarSheetAwareToolbar: ToolbarContent {
    @Environment(\.inCalendarSheet) private var inCalendarSheet

    var body: some ToolbarContent {
        if let inCalendarSheet {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    inCalendarSheet.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.primary)
                .accessibilityLabel("Close")
            }

            ToolbarItem(placement: .automatic) {
                Button("Open", systemImage: "arrow.up.forward.app") {
                    inCalendarSheet.selection.jumpToTab()
                    inCalendarSheet.dismiss()
                }
                .tint(.primary)
            }
        }
    }
}
