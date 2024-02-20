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
                let lastCheckKey = "lastCheck:\(instance.id)"

                if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
                    if Date.now.timeIntervalSince(lastCheck) < 60 {
                        status = .reachable
                        return
                    }
                }

                status = .pending

                let data = try await dependencies.api.systemStatus(instance)

                instance.version = data.version
                instance.rootFolders = try await dependencies.api.rootFolders(instance)
                instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)

                settings.saveInstance(instance)

                UserDefaults.standard.set(Date(), forKey: lastCheckKey)

                status = .reachable
            } catch is CancellationError {
                // do nothing
            } catch {
                status = .unreachable

                leaveBreadcrumb(.error, category: "movies", message: "Instance check failed", data: ["error": error])
            }
        }
    }
}
