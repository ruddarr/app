import SwiftUI
import Sentry

extension InstanceEditView {
    func createOrUpdateInstance() async {
        guard !isLoading else { return }

        let typedUrl = instance.url
        let typedAlternate = instance.alternateURL

        do {
            isLoading = true

            let schemeless = sanitizeInstanceUrl()
            try await validateInstance(schemeless: schemeless)

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
            instance.url = typedUrl
            instance.alternateURL = typedAlternate
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

        if instance.id == settings.chaptarrInstanceId {
            chaptarrInstance.switchTo(.chaptarrVoid)
        }

        settings.deleteInstance(instance)

        dependencies.router.reset()
        dependencies.router.settingsPath = .init()
    }

    func hasEmptyFields() -> Bool {
        (instance.url.isEmpty && instance.alternateURL.isEmpty) || instance.apiKey.isEmpty
    }

    func sanitizeInstanceUrl() -> (url: Bool, alternate: Bool) {
        var schemeless = (url: isSchemeless(instance.url), alternate: isSchemeless(instance.alternateURL))

        instance.url = normalizedBaseUrl(instance.url)
        instance.alternateURL = normalizedBaseUrl(instance.alternateURL)

        if instance.url.isEmpty {
            instance.url = instance.alternateURL
            instance.alternateURL = ""
            schemeless = (url: schemeless.alternate, alternate: false)
        }

        return schemeless
    }

    func isSchemeless(_ string: String) -> Bool {
        let value = string.trimmed()

        return !value.isEmpty && !value.contains("://")
    }

    private func normalizedBaseUrl(_ string: String) -> String {
        var value = string.trimmed()

        guard !value.isEmpty else { return "" }

        if isSchemeless(value) {
            value = "https://" + value
        }

        if let url = URL(string: value), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for segment in ["/system", "/settings", "/activity", "/calendar"] {
                components.path = stripAfter(segment, in: components.path)
            }

            if let urlWithoutPath = components.url {
                value = urlWithoutPath.absoluteString
            }
        }

        value = value.lowercased()

        return value.untrailingSlashIt ?? value
    }

    func stripAfter(_ path: String, in string: String) -> String {
        guard let range = string.range(of: path) else {
            return string
        }

        let after = string[range.upperBound...]

        guard after.isEmpty || after.hasPrefix("/") else {
            return string
        }

        return String(string[..<range.lowerBound])
    }

    func validateInstance(schemeless: (url: Bool, alternate: Bool)) async throws {
        try validatePrimaryURL()
        try validateAlternateURL()

        if instance.hasOnlyPrivateIpCandidates(), await NetworkMonitor.shared.localNetworkDenied {
            throw InstanceError.localNetworkDenied
        }

        if schemeless.url {
            instance.url = try await resolveScheme(of: instance.url)
        }

        if schemeless.alternate {
            instance.alternateURL = try await resolveScheme(of: instance.alternateURL)
        }

        if instance.url == instance.alternateURL {
            instance.alternateURL = ""
        }

        let status: InstanceStatus

        do {
            status = try await dependencies.api.instance.status(instance)
        } catch let apiError as API.Error {
            throw InstanceError.apiError(apiError)
        } catch {
            throw InstanceError.apiError(API.Error(from: error))
        }

        if status.appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
            throw InstanceError.badAppName(status.appName, instance.type.rawValue)
        }

        try await validateCandidateAppNames()

        instance.name = status.instanceName
        instance.version = status.version
    }

    func validateCandidateAppNames() async throws {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return }

        for base in candidates {
            guard let statusURL = URL(string: base)?.appending(path: instance.type.apiPath).appending(path: "system/status") else { continue }

            let status: InstanceStatus
            do {
                status = try await API.request(
                    url: statusURL, instance: instance,
                    timeout: RequestTimeout(local: 2.5, remote: 5), allowFailover: false
                )
            } catch {
                leaveBreadcrumb(.info, category: "instance", message: "Candidate URL unreachable during validation", data: ["error": error])
                continue
            }

            if status.appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
                throw InstanceError.badAppName(status.appName, instance.type.rawValue)
            }
        }
    }

    func resolveScheme(of url: String) async throws -> String {
        // Only auto-downgrade to cleartext http for hosts on a trusted local
        // network; never send the API key over http to a public host.
        let schemes = isLocalNetworkURL(url) ? ["https", "http"] : ["https"]

        for scheme in schemes {
            guard let candidate = replacingScheme(scheme, in: url) else {
                throw InstanceError.apiError(.invalidUrl(url))
            }

            do {
                _ = try await instanceStatus(of: candidate)

                return candidate
            } catch let apiError as API.Error {
                switch apiError {
                case .urlError, .timeoutOnPrivateIp, .notConnectedToInternet:
                    leaveBreadcrumb(.info, category: "instance", message: "Scheme unreachable", data: ["scheme": scheme, "error": apiError])
                default:
                    return candidate
                }
            } catch {
                throw InstanceError.apiError(API.Error(from: error))
            }
        }

        return url
    }

    func replacingScheme(_ scheme: String, in url: String) -> String? {
        guard var components = URLComponents(string: url) else { return nil }

        components.scheme = scheme

        return components.url?.absoluteString
    }

    func isLocalNetworkURL(_ url: String) -> Bool {
        guard let host = NetworkInterfaces.host(of: url) else { return false }

        return isPrivateIpAddress(host) || NetworkInterfaces.literalLoopback(host)
    }

    func instanceStatus(of base: String) async throws -> InstanceStatus {
        guard let url = URL(string: base)?.appending(path: instance.type.apiPath).appending(path: "system/status") else {
            throw API.Error.invalidUrl(base)
        }

        var probe = instance
        probe.url = base
        probe.alternateURL = ""

        let timeout = RequestTimeout(instance.mode.isSlow ? 5 : 2)

        return try await API.request(url: url, instance: probe, timeout: timeout, allowFailover: false)
    }

    func validateURL(
        _ string: String,
        schemeMissing: InstanceError,
        notValid: InstanceError,
        isLocal: InstanceError
    ) throws {
        guard string.starts(with: /https?:\/\//) else {
            throw schemeMissing
        }

        guard let url = URL(string: string) else {
            throw notValid
        }

        let host = NetworkInterfaces.host(of: string) ?? url.host() ?? ""

        guard !host.isEmpty else {
            throw notValid
        }

        if host == "localhost" || NetworkInterfaces.literalLoopback(host) {
            throw isLocal
        }
    }

    func validatePrimaryURL() throws {
        try validateURL(
            instance.url,
            schemeMissing: .urlSchemeMissing,
            notValid: .urlNotValid,
            isLocal: .urlIsLocal
        )
    }

    func validateAlternateURL() throws {
        guard !instance.alternateURL.isEmpty else { return }

        try validateURL(
            instance.alternateURL,
            schemeMissing: .alternateUrlSchemeMissing,
            notValid: .alternateUrlNotValid,
            isLocal: .alternateUrlIsLocal
        )

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

        if [":8789", "chaptar"].contains(where: instance.url.contains) {
            instance.type = .chaptarr
        }
    }
}
