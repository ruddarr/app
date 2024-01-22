import Foundation

class PreviewData {
    static func load<T: Codable> (name: String) -> [T] {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                return try decoder.decode([T].self, from: data)
            } catch {
                print(error)

                return []
            }
        }

        return []
    }
}
