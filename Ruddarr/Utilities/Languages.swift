import Foundation

class Languages {
    // https://localizely.com/iso-639-2-list/
    static let iso639_2: [String: String] = [
        "ara": String(localized: "Arabic"),
        "baq": String(localized: "Basque"),
        "ben": String(localized: "Bengali"),
        "bos": String(localized: "Bosnian"),
        "bra": String(localized: "Brazilian Portuguese"),
        "bul": String(localized: "Bulgarian"),
        "cat": String(localized: "Catalan"),
        "ces": String(localized: "Czech"),
        "dan": String(localized: "Danish"),
        "deu": String(localized: "German"),
        "ell": String(localized: "Greek"),
        "eng": String(localized: "English"),
        "est": String(localized: "Estonian"),
        "fas": String(localized: "Persian"),
        "fin": String(localized: "Finnish"),
        "fra": String(localized: "French"),
        "glg": String(localized: "Galician"),
        "heb": String(localized: "Hebrew"),
        "hin": String(localized: "Hindi"),
        "hrv": String(localized: "Croatian"),
        "hun": String(localized: "Hungarian"),
        "ind": String(localized: "Indonesian"),
        "isl": String(localized: "Icelandic"),
        "ita": String(localized: "Italian"),
        "jpn": String(localized: "Japanese"),
        "kor": String(localized: "Korean"),
        "lav": String(localized: "Latvian"),
        "lit": String(localized: "Lithuanian"),
        "mac": String(localized: "Macedonian"),
        "msa": String(localized: "Malay"),
        "nld": String(localized: "Dutch"),
        "nob": String(localized: "Norwegian Bokmal"),
        "nor": String(localized: "Norwegian"),
        "pol": String(localized: "Polish"),
        "por": String(localized: "Portuguese"),
        "ron": String(localized: "Romanian"),
        "rus": String(localized: "Russian"),
        "slk": String(localized: "Slovak"),
        "slv": String(localized: "Slovenian"),
        "spa": String(localized: "Spanish"),
        "srp": String(localized: "Serbian"),
        "swe": String(localized: "Swedish"),
        "tam": String(localized: "Tamil"),
        "tel": String(localized: "Telugu"),
        "tha": String(localized: "Thai"),
        "tur": String(localized: "Turkish"),
        "ukr": String(localized: "Ukrainian"),
        "vie": String(localized: "Vietnamese"),
        "zho": String(localized: "Chinese"),

        "und": String(localized: "Undetermined"),
    ]

    static let aliases: [String: String] = [
        "chi": "zho",
        "cze": "ces",
        "dut": "nld",
        "fre": "fra",
        "ger": "deu",
        "gre": "ell",
        "ice": "isl",
        "may": "msa",
        "per": "fas",
        "rum": "ron",
        "slo": "slk",
    ]

    static func name(byCode code: String) -> String {
        if let name = iso639_2[code] {
            return name
        }

        if let alias = aliases[code], let name = iso639_2[alias] {
            return name
        }

        leaveBreadcrumb(.fatal, category: "languages", message: "Missing language", data: ["code": code])

        return code
    }

    static func codeSort(_ lhs: String, _ rhs: String) -> Bool {
        let order = ["eng", "spa", "fra", "deu", "ger", "zho", "chi", "jpn", "ara", "hin"]

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
    // Canada weirdly inserts `and` between only two elements
    // `.formatted(.list(type: .and, width: .narrow))`
    func formattedList() -> String {
        joined(separator: ", ")
    }
}
