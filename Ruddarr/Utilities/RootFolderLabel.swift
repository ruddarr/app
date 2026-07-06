import Foundation

/// The pure label-disambiguation used by `InstanceRootFolder.menuLabel(among:)`, operating on
/// plain path strings with no `Instance` dependency. That is what lets this logic compile into
/// the Tests target — which has no `@testable import` — and be exercised deterministically.
///
/// Root folders are labelled by their leaf directory, but distinct folders can share one (e.g.
/// two NAS mounts both ending in `.../Media/Videos`). Starting from the leaf, path elements are
/// prepended toward the root until the trailing portion is unique among the sibling folders.
enum RootFolderLabel {
    /// A zero-width space follows each separator so long, disambiguated labels can wrap onto the
    /// next line instead of truncating.
    static let separator = "/\u{200B}"

    /// The shortest trailing portion of `path` not shared by any path in `others`.
    static func disambiguate(_ path: String, among others: [String]) -> String {
        let components = path.split(separator: "/")

        guard !components.isEmpty else {
            return path
        }

        let others = others.map { $0.split(separator: "/") }

        var depth = 1

        while depth < components.count {
            let suffix = components.suffix(depth)

            if !others.contains(where: { $0.suffix(depth) == suffix }) {
                break
            }

            depth += 1
        }

        return components.suffix(depth).joined(separator: separator)
    }
}
