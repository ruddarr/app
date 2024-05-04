import Foundation

struct MediaLanguage: Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

func languageSingleLabel(_ languages: [MediaLanguage]) -> String {
    if languages.isEmpty {
        return String(localized: "Unknown")
    }

    if languages.count == 1 {
        return languages[0].label

    }

    return String(localized: "Multilingual")
}
