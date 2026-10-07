import Foundation

/// Resolves the stored add defaults against what an instance currently offers.
enum AddDefaults {
    /// Returns the preferred quality profile if the instance has it, otherwise its first profile.
    static func qualityProfile(_ preferred: Int?, in available: [Int]) -> Int {
        if let preferred, available.contains(preferred) {
            return preferred
        }

        return available.first ?? 0
    }

    /// Returns the preferred root folder (without trailing slashes) if the instance has it, otherwise its first root folder.
    static func rootFolder(_ preferred: String?, in available: [String?]) -> String? {
        let folder = preferred?.untrailingSlashIt

        if let fallback = available.first ?? nil,
           !available.contains(where: { $0?.untrailingSlashIt == folder }) {
            return fallback
        }

        return folder
    }
}
