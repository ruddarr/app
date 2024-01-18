import Foundation

class DummyApi<Model: Codable> {
    static func call(
        method: HttpMethod = .get,
        url: URL,
        authorization: String?,
        parameters: Encodable? = nil,
        completion: @escaping (Model) -> Void,
        failure: @escaping (ApiError) -> Void
    ) async {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        switch components.path {
        case "/api/v3/movie":
            completion(self.loadPreviewData(model: Model.self, name: "movies"))
        case "/api/v3/movie/lookup":
            completion(self.loadPreviewData(model: Model.self, name: "movie-lookup"))
        default:
            fatalError("No matching DummyAPI endpoint for `\(components.path)`")
        }
    }

    static func loadPreviewData(model: Model.Type, name: String) -> Model {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let results = try JSONDecoder().decode(Model.self, from: data)

                return results
            } catch {
                fatalError("Preview data `\(name)` could not be decoded")
            }
        }

        fatalError("Preview data `\(name)` not found")
    }
}
