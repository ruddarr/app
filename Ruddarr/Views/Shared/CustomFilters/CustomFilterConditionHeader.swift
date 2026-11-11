import SwiftUI

/// A condition section's header: the condition as a sentence, and a button to remove it.
struct CustomFilterConditionHeader: View {
    let summary: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(summary)
                .textCase(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            Button(role: .destructive, action: onDelete) {
                Label("Remove condition", systemImage: "minus.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .tint(.red)
            .help("Remove condition")
        }
    }
}

/// The footer hint of a condition that has no value yet.
struct CustomFilterConditionEmptyHint: View {
    var body: some View {
        Label("Add a value to save this filter.", systemImage: "exclamationmark.circle")
            .foregroundStyle(.orange)
    }
}
