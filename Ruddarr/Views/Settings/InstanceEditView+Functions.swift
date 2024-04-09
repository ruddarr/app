import SwiftUI

extension InstanceEditView {
    @MainActor
    func createOrUpdateInstance() async {
        do {
            isLoading = true

            sanitizeInstanceUrl()
            try await validateInstance()

            if instance.label.isEmpty {
                guard let url = URL(string: instance.url), let label = url.host() else {
                    throw InstanceError.labelEmpty
                }

                instance.label = label
            }

            settings.saveInstance(instance)

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            dependencies.router.settingsPath.removeLast()
        } catch let error as InstanceError {
            isLoading = false
            showingAlert = true
            self.error = error
        } catch {
            fatalError("Failed to save instance: Unhandled error")
        }
    }

    @MainActor
    func deleteInstance() {
        deleteInstanceWebhook(instance)

        if instance.id == settings.radarrInstanceId {
            dependencies.router.reset()
            radarrInstance.switchTo(.void)
        }

        settings.deleteInstance(instance)

        dependencies.router.settingsPath = .init()
    }

    func deleteInstanceWebhook(_ deletedInstance: Instance) {
        var instance = deletedInstance
        instance.id = UUID()

        let webhook = InstanceWebhook(instance)

        Task.detached { [webhook] in
            await webhook.delete()
        }
    }

    func hasEmptyFields() -> Bool {
        instance.url.isEmpty || instance.apiKey.isEmpty
    }

    func sanitizeInstanceUrl() {
        if let url = URL(string: instance.url) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.path = ""

            if let urlWithoutPath = components.url {
                instance.url = urlWithoutPath.absoluteString
            }
        }

        instance.url = instance.url.lowercased()
    }

    func validateInstance() async throws {
        guard let url = URL(string: instance.url) else {
            throw InstanceError.urlNotValid
        }

        if !UIApplication.shared.canOpenURL(url) {
            throw InstanceError.urlNotValid
        }

        if ["localhost", "127.0.0.1"].contains(url.host()) {
            throw InstanceError.urlIsLocal
        }

        var status: InstanceStatus?

        do {
            status = try await dependencies.api.systemStatus(instance)
        } catch let apiError as API.Error {
            throw InstanceError.apiError(apiError)
        } catch {
            throw InstanceError.apiError(API.Error(from: error))
        }

        guard let appName = status?.appName else {
            return
        }

        if appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
            throw InstanceError.badAppName(appName)
        }

        instance.version = status!.version
    }

    func detectInstanceType() {
        if [":7878", ":8310", "radar"].contains(where: instance.url.contains) {
            instance.type = .radarr
        }

        if [":8989", "sonar"].contains(where: instance.url.contains) {
            instance.type = .radarr
        }
    }

    func pasteHeader() {
        guard let string = UIPasteboard.general.string else { return }

        let lines = string.components(separatedBy: .newlines)

        for line in lines {
            if line.contains(":") {
                createHeader(from: line)
            } else {
                appendHeader(from: line.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    func createHeader(from line: String) {
        let components = line.components(separatedBy: ":").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        instance.headers.append(InstanceHeader(
            name: components[0],
            value: components[1]
        ))
    }

    func appendHeader(from value: String) {
        if var header = instance.headers.last {
            let index = instance.headers.count - 1

            if header.name.isEmpty {
                header.name = value
                instance.headers[index] = header
            } else if header.value.isEmpty {
                header.value = value
                instance.headers[index] = header
            } else {
                instance.headers.append(InstanceHeader(name: value, value: ""))
            }
        } else {
            instance.headers.append(InstanceHeader(name: value, value: ""))
        }
    }
}

extension InstanceEditView {
    var debugQuickFill: some View {
        Group {
            Button {
                instance.label = "Dummy"
                instance.url = "https://dummyjson.com/products/1"
                instance.apiKey = "fake"
            } label: {
                Text(verbatim: "Dummy")
            }

            Button {
                instance.label = "Syno Radarr"
                instance.url = Instance.radarr.url
                instance.apiKey = Instance.radarr.apiKey
            } label: {
                Text(verbatim: "Synology: Radarr")
            }

            Button {
                instance.type = .sonarr
                instance.label = "Syno Sonarr"
                instance.url = Instance.sonarr.url
                instance.apiKey = Instance.sonarr.apiKey
            } label: {
                Text(verbatim: "Synology: Sonarrr")
            }

            Button{
                self.instance.label = "Digital Ocean"
                self.instance.url = Instance.digitalOcean.url
                self.instance.apiKey = Instance.digitalOcean.apiKey
            } label: {
                Text(verbatim: "Digital Ocean")
            }
        }
    }
}
