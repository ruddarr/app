import SwiftUI

struct CommandListItem: View {
    var command: CommandItem

    var body: some View {
        VStack(alignment: .leading) {
            Text(command.titleLabel)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(command.statusLabel)

                Bullet()
                Text(command.triggerLabel)

                if let message = command.message, !message.isEmpty {
                    Bullet()
                    Text(message)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
