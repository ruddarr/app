import os
import SwiftUI

struct InstanceRow: View {
    @Binding var instance: Instance

    @State private var status: Status = .pending

    @EnvironmentObject var settings: AppSettings

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
                status = .pending

                // TODO: Let's only synchonize every 60 seconds
                let data = try await dependencies.api.systemStatus(instance)

                instance.version = data.version
                instance.rootFolders = try await dependencies.api.rootFolders(instance)
                instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)

                settings.saveInstance(instance)

                status = .reachable
            } catch is CancellationError {
                // do nothing when task is cancelled
            } catch {
                status = .unreachable

                leaveBreadcrumb(.error, category: "movies", message: "Instance check failed", data: ["error": error])
            }
        }
    }
}
