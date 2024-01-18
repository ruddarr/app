import Foundation

extension API {
    static var mock: Self {
        .init(fetchMovies: { instance in
           loadPreviewData(filename: "movies")
        })
    }
}

fileprivate extension API {
    static func loadPreviewData<Model: Decodable>(filename: String) -> Model {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let results = try JSONDecoder().decode(Model.self, from: data)
                
                return results
            } catch {
                fatalError("Preview data `\(filename)` could not be decoded")
            }
        }
        fatalError("Preview data `\(filename)` not found")
    }
}
