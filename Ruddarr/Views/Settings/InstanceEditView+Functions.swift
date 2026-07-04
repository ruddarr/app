import SwiftUI

extension InstanceEditView {
    func createOrUpdateInstance() async {
        do {
            isLoading = true

            sanitizeInstanceUrl()
            try await validateInstance()

            instance.label = instance.label.trimmed()

            if instance.label.isEmpty {
                instance.label = instance.type.rawValue
            }

            settings.saveInstance(instance)

            #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                if !dependencies.router.settingsPath.isEmpty {
                    dependencies.router.settingsPath.removeLast()
                }
            #else
                dismiss()
            #endif
        } catch let error as InstanceError {
            isLoading = false
            showingAlert = true
            self.error = error
        } catch {
            fatalError("Failed to save instance: Unhandled error")
        }
    }

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
        (instance.url.isEmpty && instance.alternateURL.isEmpty) || instance.apiKey.isEmpty
    }

    func sanitizeInstanceUrl() {
        instance.url = sanitizedUrl(instance.url)
        instance.alternateURL = sanitizedUrl(instance.alternateURL)

        if instance.url.isEmpty {
            instance.url = instance.alternateURL
            instance.alternateURL = ""
        }
    }

    func sanitizedUrl(_ string: String) -> String {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return "" }

        if let url = URL(string: value), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.path = stripAfter("/system", in: components.path)
            components.path = stripAfter("/settings", in: components.path)
            components.path = stripAfter("/activity", in: components.path)
            components.path = stripAfter("/calendar", in: components.path)

            if let urlWithoutPath = components.url {
                value = urlWithoutPath.absoluteString
            }
        }

        value = value.lowercased()

        if value.hasSuffix("/") {
            value = String(value.dropLast())
        }

        return value
    }

    func stripAfter(_ path: String, in string: String) -> String {
        guard let range = string.range(of: path) else {
            return string
        }

        return String(string[..<range.lowerBound])
    }

    func validateInstance() async throws {
        try validatePrimaryURL()
        try validateAlternateURL()

        if instance.hasOnlyPrivateIpCandidates(), await NetworkMonitor.shared.localNetworkDenied {
            throw InstanceError.localNetworkDenied
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
            throw InstanceError.badAppName(appName, instance.type.rawValue)
        }

        if let status {
            instance.name = status.instanceName
            instance.version = status.version
        }
    }

    func validatePrimaryURL() throws {
        guard instance.url.starts(with: /https?:\/\//) else {
            throw InstanceError.urlSchemeMissing
        }

        guard let url = URL(string: instance.url) else {
            throw InstanceError.urlNotValid
        }

        let host = NetworkInterfaces.host(of: instance.url) ?? url.host() ?? ""
        if host == "localhost" || NetworkInterfaces.literalLoopback(host) {
            throw InstanceError.urlIsLocal
        }
    }

    func validateAlternateURL() throws {
        guard !instance.alternateURL.isEmpty else { return }

        guard instance.alternateURL.starts(with: /https?:\/\//) else {
            throw InstanceError.alternateUrlSchemeMissing
        }

        guard let alternateURL = URL(string: instance.alternateURL) else {
            throw InstanceError.alternateUrlNotValid
        }

        let alternateHost = NetworkInterfaces.host(of: instance.alternateURL) ?? alternateURL.host() ?? ""

        if alternateHost == "localhost" || NetworkInterfaces.literalLoopback(alternateHost) {
            throw InstanceError.alternateUrlIsLocal
        }

        if instance.candidateURLs.count < 2 {
            throw InstanceError.alternateSameAsUrl
        }
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
