import Foundation

class Languages {
    static let iso3166: [String: String] = [
        "eng": "English",
        "fra": "French",
        "spa": "Spanish",
        "deu": "German",
        "ita": "Italian",
        "dan": "Danish",
        "nld": "Dutch",
        "jpn": "Japanese",
        "isl": "Icelandic",
        "zho": "Chinese",
        "rus": "Russian",
        "pol": "Polish",
        "vie": "Vietnamese",
        "swe": "Swedish",
        "nor": "Norwegian",
        "nob": "Norwegian Bokmal",
        "fin": "Finnish",
        "tur": "Turkish",
        "por": "Portuguese",
        "ell": "Greek",
        "kor": "Korean",
        "hun": "Hungarian",
        "heb": "Hebrew",
        "ces": "Czech",
        "hin": "Hindi",
        "tha": "Thai",
        "bul": "Bulgarian",
        "ron": "Romanian",
        "bra": "Portuguese (Brazil)",
        "ara": "Arabic",
        "ukr": "Ukrainian",
        "fas": "Persian",
        "ben": "Bengali",
        "lit": "Lithuanian",
        "slk": "Slovak",
        "lav": "Latvian",
        "cat": "Catalan",
        "hrv": "Croatian",
        "srp": "Serbian",
        "bos": "Bosnian",
        "est": "Estonian",
        "tam": "Tamil",
        "ind": "Indonesian",
        "tel": "Telugu",
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

        leaveBreadcrumb(.error, category: "languages", message: "Missing language", data: ["code": code])

        return code
    }

    static func codeSort(_ lhs: String, _ rhs: String) -> Bool {
        let order = ["eng", "spa", "fra", "deu", "ger", "zho", "chi", "jpn", "ara", "hin"]

        let index1 = order.firstIndex(of: lhs) ?? Int.max
        let index2 = order.firstIndex(of: rhs) ?? Int.max

        return index1 < index2 || (index1 == index2 && lhs < rhs)
    }
}
