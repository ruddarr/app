import SwiftUI
import Sentry

extension InstanceEditView {
    func createOrUpdateInstance() async {
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

    /// Normalizes both URL fields, provisionally assuming `https://` where no scheme was typed, and
    /// reports which fields got that provisional scheme so `validateInstance` knows it may fall back
    /// to `http://` for them.
    func sanitizeInstanceUrl() -> (url: Bool, alternate: Bool) {
        var schemeless = (url: isSchemeless(instance.url), alternate: isSchemeless(instance.alternateURL))

        instance.url = sanitizedUrl(instance.url)
        instance.alternateURL = sanitizedUrl(instance.alternateURL)

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

    /// Strips the web UI paths a pasted URL may carry, and gives scheme-less input a provisional
    /// `https://` before anything parses it: a scheme may contain dots, so `URL(string:)` reads a
    /// bare `sonarr.home.net:8989` as the scheme `sonarr.home.net` with the path `8989`.
    func sanitizedUrl(_ string: String) -> String {
        var value = string.trimmed()

        guard !value.isEmpty else { return "" }

        if isSchemeless(value) {
            value = "https://" + value
        }

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

        return value.untrailingSlashIt ?? value
    }

    func stripAfter(_ path: String, in string: String) -> String {
        guard let range = string.range(of: path) else {
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

        var status: InstanceStatus?

        if schemeless.url {
            (instance.url, status) = try await resolveScheme(of: instance.url)
        }

        if schemeless.alternate {
            (instance.alternateURL, _) = try await resolveScheme(of: instance.alternateURL)
        }

        if status == nil {
            do {
                status = try await dependencies.api.systemStatus(instance)
            } catch let apiError as API.Error {
                throw InstanceError.apiError(apiError)
            } catch {
                throw InstanceError.apiError(API.Error(from: error))
            }
        }

        guard let appName = status?.appName else {
            return
        }

        if appName.caseInsensitiveCompare(instance.type.rawValue) != .orderedSame {
            throw InstanceError.badAppName(appName, instance.type.rawValue)
        }

        try await validateCandidateAppNames()

        if let status {
            instance.name = status.instanceName
            instance.version = status.version
        }
    }

    func validateCandidateAppNames() async throws {
        let candidates = instance.candidateURLs
        guard candidates.count > 1 else { return }

        let selected = await InstanceResolver.shared.currentSelection(for: instance)

        for base in candidates where base != selected {
            guard let statusURL = URL(string: base)?.appending(path: "/api/v3/system/status") else { continue }

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

    /// Determines whether a URL the user entered without a scheme answers over HTTPS or HTTP, and
    /// returns it with the winning scheme along with the status it responded with.
    ///
    /// HTTPS is always tried first, and never concurrently: a TLS handshake against a plaintext port
    /// fails before the request is sent, so the API key stays off the wire, whereas a plaintext
    /// request to a TLS port puts the key there in the clear. Only a transport failure falls through
    /// to HTTP — an HTTP response of any kind, including a 401, proves the scheme is right and the
    /// fault lies elsewhere, so that error is surfaced instead of retrying the key unencrypted.
    func resolveScheme(of url: String) async throws -> (String, InstanceStatus) {
        var transportFailure: API.Error?

        for scheme in ["https", "http"] {
            guard let candidate = replacingScheme(scheme, in: url) else {
                throw InstanceError.apiError(.invalidUrl(url))
            }

            do {
                return (candidate, try await instanceStatus(of: candidate))
            } catch let apiError as API.Error where apiError.isTransportFailure {
                leaveBreadcrumb(.info, category: "instance", message: "Scheme unreachable", data: ["scheme": scheme, "error": apiError])

                transportFailure = apiError
            } catch let apiError as API.Error {
                throw InstanceError.apiError(apiError)
            } catch {
                throw InstanceError.apiError(API.Error(from: error))
            }
        }

        throw InstanceError.apiError(transportFailure ?? .void)
    }

    func replacingScheme(_ scheme: String, in url: String) -> String? {
        guard var components = URLComponents(string: url) else { return nil }

        components.scheme = scheme

        return components.url?.absoluteString
    }

    func instanceStatus(of base: String) async throws -> InstanceStatus {
        guard let url = URL(string: base)?.appending(path: "/api/v3/system/status") else {
            throw API.Error.invalidUrl(base)
        }

        var probe = instance
        probe.url = base
        probe.alternateURL = ""

        return try await API.request(url: url, instance: probe, timeout: RequestTimeout(2), allowFailover: false)
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
