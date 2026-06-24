import SwiftUI

struct CalendarAwareToolbarMenu<Menu: ToolbarContent>: ToolbarContent {
    private let menu: () -> Menu

    init(@ToolbarContentBuilder menu: @escaping () -> Menu) {
        self.menu = menu
    }

    var body: some ToolbarContent {
        // Keep the view's own actions (monitor, overflow menu, …) and, when
        // presented inside the calendar sheet, add the close/jump buttons.
        menu()
        CalendarSheetToolbarContent()
    }
}

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
                .accessibilityLabel("Dismiss")
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Jump", systemImage: "arrow.up.forward.app") {
                    calendarSheetContext.selection.jumpToTab()
                    calendarSheetContext.dismiss()
                }
                .tint(.primary)
            }
        }
    }
}
