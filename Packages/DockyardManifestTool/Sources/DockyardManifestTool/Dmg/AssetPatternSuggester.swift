import Foundation

enum AssetPatternSuggester {

    /// Suggests an anchored asset regex from a concrete DMG name by replacing
    /// its version run with a wildcard, e.g. "Automata-1.0.0.dmg" →
    /// `^Automata-.*\.dmg$`. Returns nil when the name has no version run to
    /// generalize (the first-`*.dmg` fallback works fine there).
    static func suggest(assetName: String) -> String? {
        guard assetName.lowercased().hasSuffix(".dmg") else { return nil }
        let versionRegex = /[0-9]+(?:\.[0-9]+)+/
        guard let match = assetName.firstMatch(of: versionRegex) else { return nil }
        let prefix = String(assetName[..<match.range.lowerBound])
        let suffix = String(assetName[match.range.upperBound...])
        return "^"
            + NSRegularExpression.escapedPattern(for: prefix)
            + ".*"
            + NSRegularExpression.escapedPattern(for: suffix)
            + "$"
    }
}
