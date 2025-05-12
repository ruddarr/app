import Foundation
import CloudKit

protocol OptionalProtocol {
    associatedtype Wrapped
    var wrappedValue: Wrapped? { get set }
}

extension Optional: OptionalProtocol {
    var wrappedValue: Wrapped? {
        get { self }
        set { self = newValue }
    }
}

extension String {
    var untrailingSlashIt: String? {
        var string = self

        while string.hasSuffix("/") {
            string = String(string.dropLast())
        }

        return string
    }

    func toMarkdown() -> AttributedString {
        do {
            return try AttributedString(markdown: self)
        } catch {
            print("Error parsing Markdown for string \(self): \(error)")

            return AttributedString(self)
        }
    }

    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func breakable() -> String {
        self.replacingOccurrences(of: ".", with: ".\u{200B}")
    }

    func isValidEmail() -> Bool {
        self.wholeMatch(of: /(?i)^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/) != nil
    }
}

extension UUID {
    func isEqual(to string: String) -> Bool {
        self.uuidString.caseInsensitiveCompare(string) == .orderedSame
    }

    var shortened: String {
        self.uuidString.prefix(8).lowercased()
    }
}

extension Hashable {
    func equals(_ other: any Hashable) -> Bool {
        if type(of: self) != type(of: other) {
            return false
        }

        if let other = other as? Self {
            return self == other
        }

        return false
    }
}

extension CKRecord.ID {
    static var mock: Self {
        .init(recordName: "_00000000000000000000000000000000")
    }
}

func inferredInstallDate() -> Date? {
    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
        return nil
    }

    guard let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path) else {
        return nil
    }

    return attributes[.creationDate] as? Date
}

func calculateBitrate(_ seconds: Int, _ bytes: Int) -> Int? {
    guard seconds > 0 else { return nil }
    return (bytes * 8) / seconds
}

func calculateRuntime(_ runtime: String?) -> Int? {
    guard let runtime, !runtime.isEmpty else { return nil }

    return runtime.split(separator: ":")
        .compactMap { Int($0) }
        .reduce(0) { $0 * 60 + $1 }
}

func extractImdbId(_ text: String) -> String? {
    let pattern = /imdb\.com\/title\/(tt\d+)/

    if let matches = try? pattern.firstMatch(in: text) {
        return String(matches.1)
    }

    return nil
}

func cloudKitStatusString(_ status: CKAccountStatus?) -> String {
    switch status {
    case .couldNotDetermine: "could-not-determine"
    case .available: "available"
    case .restricted: "restricted"
    case .noAccount: "no-account"
    case .temporarilyUnavailable: "temporarily-unavailable"
    case .none: "nil"
    @unknown default: "unknown"
    }
}

class PreviewData {
    static func load<T: Codable> (name: String) -> [T] {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601extended

                return try decoder.decode([T].self, from: data)
            } catch {
                print("Could not load preview data: \(error)")
                fatalError("Could not load preview data: \(error)")
            }
        }

        print("Invalid preview data path: \(name)")
        fatalError("Invalid preview data path: \(name)")
    }

    static func loadObject<T: Codable> (name: String) -> T {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601extended

                return try decoder.decode(T.self, from: data)
            } catch {
                print("Could not load preview data: \(error)")
                fatalError("Could not load preview data: \(error)")
            }
        }

        print("Invalid preview data path: \(name)")
        fatalError("Invalid preview data path: \(name)")
    }
}
