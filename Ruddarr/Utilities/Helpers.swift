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
