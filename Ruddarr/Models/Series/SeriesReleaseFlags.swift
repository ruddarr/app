struct SeriesReleaseFlags {
    static let map: [Int: SeriesReleaseFlag] = [
        1: .freeleech,
        2: .halfleech,
        4: .doubleUpload,
        8: .internal,
        16: .scene,
        32: .freeleech75,
        64: .freeleech25,
        128: .nuked,
    ]

    static func parse(_ value: Int) -> [SeriesReleaseFlag] {
        map.keys.sorted().filter { value & $0 != 0 }.compactMap { map[$0] }
    }
}

enum SeriesReleaseFlag {
    case freeleech
    case halfleech
    case doubleUpload
    case `internal`
    case scene
    case freeleech75
    case freeleech25
    case nuked

    var label: String {
        switch self {
        case .freeleech: "Freeleech"
        case .halfleech: "Halfleech"
        case .doubleUpload: "DoubleUpload"
        case .internal: "Internal"
        case .scene: "Scene"
        case .freeleech75: "Freeleech75"
        case .freeleech25: "Freeleech25"
        case .nuked: "Nuked"
        }
    }
}
