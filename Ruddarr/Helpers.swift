import Foundation

class Helpers {
    
    class func validateURL(_ url: URL, _ completion: @escaping ((Bool)->())) {
        // Create a URLRequest with the specified URL
        let request = URLRequest(url: url)
        
        // Perform an asynchronous request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                // Check if the response status code is 200
                completion(httpResponse.statusCode == 200)
            } else {
                // If there was an error or the response is not an HTTP response, return false
                completion(false)
            }
        }.resume()
    }
    
}



