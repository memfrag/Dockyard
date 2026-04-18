import Foundation

enum AssetSelectorError: Error, CustomStringConvertible {
    case noMatchingAsset(candidates: [String], pattern: String?)

    var description: String {
        switch self {
        case .noMatchingAsset(let candidates, let pattern):
            let p = pattern ?? "(fallback: first *.dmg)"
            return "No DMG asset matched \(p); candidates: \(candidates.joined(separator: ", "))"
        }
    }
}

enum AssetSelector {

    static func select(from assets: [GitHubAsset], pattern: String?) throws -> GitHubAsset {
        let dmgCandidates = assets.filter { $0.name.lowercased().hasSuffix(".dmg") }

        if let pattern {
            let regex = try NSRegularExpression(pattern: pattern)
            if let matched = assets.first(where: { asset in
                let range = NSRange(asset.name.startIndex..<asset.name.endIndex, in: asset.name)
                return regex.firstMatch(in: asset.name, range: range) != nil
            }) {
                return matched
            }
            throw AssetSelectorError.noMatchingAsset(candidates: assets.map(\.name), pattern: pattern)
        }

        if let first = dmgCandidates.first {
            return first
        }
        throw AssetSelectorError.noMatchingAsset(candidates: assets.map(\.name), pattern: nil)
    }
}
