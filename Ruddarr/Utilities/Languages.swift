import Foundation

class Languages {
    static let iso3166: [String: String] = [
        "eng": String(localized: "English"),
        "fra": String(localized: "French"),
        "spa": String(localized: "Spanish"),
        "deu": String(localized: "German"),
        "ita": String(localized: "Italian"),
        "dan": String(localized: "Danish"),
        "nld": String(localized: "Dutch"),
        "jpn": String(localized: "Japanese"),
        "isl": String(localized: "Icelandic"),
        "zho": String(localized: "Chinese"),
        "rus": String(localized: "Russian"),
        "pol": String(localized: "Polish"),
        "vie": String(localized: "Vietnamese"),
        "swe": String(localized: "Swedish"),
        "nor": String(localized: "Norwegian"),
        "nob": String(localized: "Norwegian Bokmal"),
        "fin": String(localized: "Finnish"),
        "tur": String(localized: "Turkish"),
        "por": String(localized: "Portuguese"),
        "ell": String(localized: "Greek"),
        "kor": String(localized: "Korean"),
        "hun": String(localized: "Hungarian"),
        "heb": String(localized: "Hebrew"),
        "ces": String(localized: "Czech"),
        "hin": String(localized: "Hindi"),
        "tha": String(localized: "Thai"),
        "bul": String(localized: "Bulgarian"),
        "ron": String(localized: "Romanian"),
        "bra": String(localized: "Brazilian Portuguese"),
        "ara": String(localized: "Arabic"),
        "ukr": String(localized: "Ukrainian"),
        "fas": String(localized: "Persian"),
        "ben": String(localized: "Bengali"),
        "lit": String(localized: "Lithuanian"),
        "slk": String(localized: "Slovak"),
        "slv": String(localized: "Slovenian"),
        "lav": String(localized: "Latvian"),
        "cat": String(localized: "Catalan"),
        "hrv": String(localized: "Croatian"),
        "srp": String(localized: "Serbian"),
        "bos": String(localized: "Bosnian"),
        "est": String(localized: "Estonian"),
        "tam": String(localized: "Tamil"),
        "ind": String(localized: "Indonesian"),
        "tel": String(localized: "Telugu"),
        "msa": String(localized: "Malay"),

        "und": String(localized: "Undetermined"),
    ]

    static let iso639: [String: String] = [
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
        if let name = iso3166[code] {
            return name
        }

        if let alias = iso639[code], let name = iso3166[alias] {
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
