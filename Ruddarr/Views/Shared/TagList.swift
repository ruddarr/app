import SwiftUI

struct TagList: View {
    @Binding var selected: Set<Tag.ID>
    var tags: [Tag]

    var body: some View {
        List(tags) { tag in
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
        .navigationTitle("Tags")
    }
}

struct TagMenu: View {
    @Binding var selected: Set<Tag.ID>
    var tags: [Tag]

    var body: some View {
        Menu {
            ForEach(tags) { tag in
                Button {
                    if selected.contains(tag.id) {
                        selected.remove(tag.id)
                    } else {
                        selected.insert(tag.id)
                    }
                } label: {
                    HStack {
                        Text(tag.label)

                        if selected.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        } label: {
            Text(formatTags(Array(selected), tags: tags))
        }
        .tint(.secondary)
    }
}
