import Foundation
import SwiftUI

@Observable
final class Router {
    static let shared = Router()
    
    var selectedTab: Tab = .movies
    
    var moviesPath: NavigationPath = .init()
}
