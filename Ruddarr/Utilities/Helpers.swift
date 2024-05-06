import Foundation

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
}

func formatRuntime(_ runtime: Int) -> String {
    let hours = runtime / 60
    let minutes = runtime % 60

    if hours == 0 {
        return String(format: String(localized: "%dm", comment: "%d = minutes (13m)"), minutes)
    }

    return String(format: String(localized: "%dh %dm", comment: "$1 = hours, $2 = minutes (1h 13m)"), hours, minutes)
}

func formatBytes(_ bytes: Int, adaptive: Bool = false) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary

    if adaptive {
        formatter.isAdaptive = bytes < 1_073_741_824 // 1 GB
    }

    return formatter.string(fromByteCount: Int64(bytes))
}

class PreviewData {
    static func load<T: Codable> (name: String) -> [T] {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                return try decoder.decode([T].self, from: data)
            } catch {
                print("Could not load preview data: \(error)")
                fatalError("Could not load preview data: \(error)")
            }
        }

        print("Invalid preview data path: \(name)")
        fatalError("Invalid preview data path: \(name)")
    }
}
