import os
import SwiftUI

struct InstanceRow: View {
    var instance: Instance
    private let log: Logger = logger("settings")

    @EnvironmentObject var settings: AppSettings

    @State private var status: Status = .pending

    enum Status {
        case pending
        case reachable
        case unreachable
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(instance.label)

            HStack {
                switch status {
                case .pending: Text("Connecting...")
                case .reachable: Text("Connected")
                case .unreachable: Text("Connection failed").foregroundStyle(.red)
                }
            }
            .font(.footnote)
            .foregroundStyle(.gray)
        }.task {
            do {
                _ = try await dependencies.api.systemStatus(instance)
                try await settings.fetchInstanceMetadata(instance.id)
                status = .reachable
            } catch {
                log.error("Instance check failed: \(error)")
                status = .unreachable
            }
        }
    }
}
