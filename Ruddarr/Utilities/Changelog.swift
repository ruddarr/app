import Foundation

struct ChangelogRelease: Identifiable {
    let version: String
    let date: Date?
    let rawDate: String
    let note: String?
    let sections: [ChangelogSection]

    var id: String { version }

    var formattedDate: String {
        guard let date else { return rawDate }
        return date.formatted(.dateTime.year().month(.abbreviated).day())
    }
}

struct ChangelogSection: Identifiable {
    let kind: ChangelogKind
    let body: String

    var id: String { kind.rawValue }

    var bullets: [String] {
        body.components(separatedBy: "\n").map {
            $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0
        }
    }
}

enum ChangelogKind: String, CaseIterable {
    case added = "Added"
    case changed = "Changed"
    case deprecated = "Deprecated"
    case removed = "Removed"
    case fixed = "Fixed"
    case security = "Security"
}

enum ChangelogParser {
    static let all: [ChangelogRelease] = load()

    static func load() -> [ChangelogRelease] {
        guard
            let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }

        return parse(text)
    }

    static func parse(_ text: String) -> [ChangelogRelease] {
        var releases: [ChangelogRelease] = []

        var version: String?
        var rawDate = ""
        var date: Date?
        var kind: ChangelogKind?
        var order: [ChangelogKind] = []
        var noteLines: [String] = []
        var linesByKind: [ChangelogKind: [String]] = [:]

        func flush() {
            guard let version else { return }

            let sections = order.compactMap { kind -> ChangelogSection? in
                guard let lines = linesByKind[kind], !lines.isEmpty else { return nil }
                return ChangelogSection(kind: kind, body: lines.joined(separator: "\n"))
            }

            let note = noteLines.isEmpty ? nil : noteLines.joined(separator: "\n")

            // Skip empty releases, e.g. an "Unreleased" heading with nothing under it yet.
            guard note != nil || !sections.isEmpty else { return }

            releases.append(
                ChangelogRelease(version: version, date: date, rawDate: rawDate, note: note, sections: sections)
            )
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("## ") {
                flush()
                version = nil
                rawDate = ""
                date = nil
                kind = nil
                order = []
                noteLines = []
                linesByKind = [:]

                let heading = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)

                if let separator = heading.range(of: " - ") {
                    version = String(heading[..<separator.lowerBound]).trimmingCharacters(in: .whitespaces)
                    rawDate = String(heading[separator.upperBound...]).trimmingCharacters(in: .whitespaces)
                    date = isoDate(rawDate)
                } else {
                    version = heading.trimmingCharacters(in: .whitespaces)
                }
            } else if line.hasPrefix("### ") {
                let name = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                kind = ChangelogKind(rawValue: name)

                if let kind, !order.contains(kind) {
                    order.append(kind)
                }
            } else if line.hasPrefix("- "), let kind {
                linesByKind[kind, default: []].append(line)
            } else if !line.isEmpty, version != nil, kind == nil {
                noteLines.append(line)
            }
        }

        flush()

        return releases
    }

    static func isoDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.date(from: string)
    }
}
