import Foundation

class Languages {
    // https://en.wikipedia.org/wiki/List_of_ISO_639-2_codes
    static let iso639_2: [String: String] = [
        "mis": String(localized: "Uncoded", comment: "Label for uncoded languages"),
        "und": String(localized: "Undetermined", comment: "Label for unknown/undetermined language"),
    ]

    static func name(byCode code: String) -> String {
        if code.count > 3 {
            return code
        }

        if let name = iso639_2[code] {
            return name
        }

        if let name = Locale.current.localizedString(forLanguageCode: code) {
            return String(name.split(separator: "-")[0])
        }

        if code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "und"
        }

        leaveBreadcrumb(.fatal, category: "languages", message: "Missing language", data: ["code": code])

        return code
    }

    static func codeSort(_ lhs: String, _ rhs: String) -> Bool {
        let order = ["eng", "spa", "fre", "fra", "deu", "ger", "zho", "chi", "jpn", "ara", "hin"]

        let index1 = order.firstIndex(of: lhs) ?? Int.max
        let index2 = order.firstIndex(of: rhs) ?? Int.max

        return index1 < index2 || (index1 == index2 && lhs < rhs)
    }
}

func languagesList(_ codes: [String]) -> String {
    codes.map {
        $0.replacingOccurrences(of: $0, with: Languages.name(byCode: $0))
    }.formattedList()
}

extension Array where Element: StringProtocol {
    // Some regions weirdly insert `and` between only two elements
    // `.formatted(.list(type: .and, width: .narrow))`
    func formattedList() -> String {
        joined(separator: ", ")
    }
}
