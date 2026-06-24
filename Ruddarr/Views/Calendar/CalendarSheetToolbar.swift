import SwiftUI

struct CalendarSheetToolbarContent: ToolbarContent {
    @Environment(\.calendarSheetContext) private var calendarSheetContext

    var body: some ToolbarContent {
        if let calendarSheetContext {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    calendarSheetContext.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.primary)
                .accessibilityLabel("Close")
            }

            ToolbarItem(placement: .automatic) {
                Button("Open", systemImage: "arrow.up.forward.app") {
                    calendarSheetContext.selection.jumpToTab()
                    calendarSheetContext.dismiss()
                }
                .tint(.primary)
            }
        }
    }
}
