import SwiftUI

extension InstanceEditView {
    @MainActor
    func createOrUpdateInstance() async {
        do {
            isLoading = true

            sanitizeInstanceUrl()
            try await validateInstance()

            if instance.label.isEmpty {
                instance.label = instance.type.rawValue
            }

            settings.saveInstance(instance)

            #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif

            if !dependencies.router.settingsPath.isEmpty {
                dependencies.router.settingsPath.removeLast()
            }
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
        if instance.id == settings.radarrInstanceId {
            radarrInstance.switchTo(.radarrVoid)
        }

        if instance.id == settings.sonarrInstanceId {
            sonarrInstance.switchTo(.sonarrVoid)
        }

        settings.deleteInstance(instance)

        dependencies.router.reset()
        dependencies.router.settingsPath = .init()
    }

    func hasEmptyFields() -> Bool {
        instance.url.isEmpty || instance.apiKey.isEmpty
    }

    func sanitizeInstanceUrl() {
        if let url = URL(string: instance.url) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

            components.path = stripAfter("/system", in: components.path)
            components.path = stripAfter("/settings", in: components.path)
            components.path = stripAfter("/activity", in: components.path)
            components.path = stripAfter("/calendar", in: components.path)

            if let urlWithoutPath = components.url {
                instance.url = urlWithoutPath.absoluteString
            }
        }

        instance.url = instance.url.lowercased()

        if instance.url.hasSuffix("/") {
            instance.url = String(instance.url.dropLast())
        }
    }

    func stripAfter(_ path: String, in string: String) -> String {
        guard let range = string.range(of: path) else {
            return string
        }

        return String(string[..<range.lowerBound])
    }

    func validateInstance() async throws {
        guard let url = URL(string: instance.url) else {
            throw InstanceError.urlNotValid
        }

        #if os(iOS)
            if !UIApplication.shared.canOpenURL(url) {
                throw InstanceError.urlNotValid
            }
        #endif

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
            instance.type = .sonarr
        }
    }

    func pasteHeader() {
        #if os(macOS)
            let string = ""
        #else
            guard let string = UIPasteboard.general.string else { return }
        #endif

        let lines = string.components(separatedBy: .newlines)

        for line in lines {
            if line.contains(":") {
                createHeader(from: line)
            } else {
                appendHeader(from: line)
            }
        }
    }

    func createHeader(from line: String) {
        let components = line.components(separatedBy: ":")

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
