import Foundation

extension API {
    static var mock: Self {
        .init(fetchMovies: { instance in
            []
        })
    }
}
