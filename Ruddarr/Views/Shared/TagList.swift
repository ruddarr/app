import SwiftUI

struct TagList: View {
    @Binding var selected: Set<Tag.ID>

    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        List(instance.tags) { tag in
            Button {
                if selected.contains(tag.id) {
                    selected.remove(tag.id)
                } else {
                    selected.insert(tag.id)
                }
            } label: {
                HStack {
                    Text(tag.label)
                    Spacer()

                    if selected.contains(tag.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
