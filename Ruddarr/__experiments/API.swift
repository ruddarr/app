import Foundation

class API {
    func movies() async throws -> [Movie]? {
        let urlString = "http://10.0.1.5:8310/api/v3/movie"
        
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("8f45bce99e254f888b7a2ba122468dbe", forHTTPHeaderField: "X-Api-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        
        return try JSONDecoder().decode([Movie].self, from: data)
    }
}
