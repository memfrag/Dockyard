//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftUIToolbox
import AppDesign
import DockyardEngine

struct CatalogPane: View {

    let title: String
    let pretitle: String
    let category: String?
    let sectionTitle: String
    let emptyTitle: String
    let emptyMessage: String
    let subtitle: (DockyardEngine, [CatalogEntry]) -> String
    let searchQuery: String?
    let extraFilter: ((CatalogEntry) -> Bool)?

    init(
        title: String,
        category: String?,
        sectionTitle: String,
        emptyTitle: String,
        emptyMessage: String,
        subtitle: @escaping (DockyardEngine, [CatalogEntry]) -> String,
        pretitle: String = "Category",
        searchQuery: String? = nil,
        extraFilter: ((CatalogEntry) -> Bool)? = nil
    ) {
        self.title = title
        self.pretitle = pretitle
        self.category = category
        self.sectionTitle = sectionTitle
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.subtitle = subtitle
        self.searchQuery = searchQuery
        self.extraFilter = extraFilter
    }

    @Environment(DockyardEngine.self) private var engine

    @State private var iconURLs: [CatalogEntry.ID: URL] = [:]
    @State private var navigationPath = NavigationPath()

    private var entries: [CatalogEntry] {
        var result = engine.catalog
        if let category {
            result = result.filter { $0.category == category }
        }
        if let extraFilter {
            result = result.filter(extraFilter)
        }
        guard let tokens = searchTokens else { return result }
        return Self.rank(entries: result, against: tokens)
    }

    private var searchTokens: [String]? {
        guard let query = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else { return nil }
        return query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    // MARK: - Ranking

    /// Two-tier ranking:
    /// 1. Entries where every token has a direct substring match (locale-aware,
    ///    case- and diacritic-insensitive). Ordered by total fuzzy score.
    /// 2. Entries where every token is at least a subsequence match. Ordered by
    ///    total fuzzy score. Shown after all substring-tier results.
    /// Entries that fail to match at least one token on both tiers are excluded.
    private static func rank(entries: [CatalogEntry], against tokens: [String]) -> [CatalogEntry] {
        var substringTier: [(entry: CatalogEntry, score: Double)] = []
        var fuzzyTier: [(entry: CatalogEntry, score: Double)] = []

        for entry in entries {
            let haystack = [entry.displayName, entry.summary, entry.category].joined(separator: " ")

            let hasSubstringForAll = tokens.allSatisfy { haystack.localizedStandardContains($0) }
            guard let score = totalFuzzyScore(tokens: tokens, haystack: haystack) else {
                // No subsequence match for at least one token — drop it.
                continue
            }
            if hasSubstringForAll {
                substringTier.append((entry, score))
            } else {
                fuzzyTier.append((entry, score))
            }
        }

        substringTier.sort { $0.score > $1.score }
        fuzzyTier.sort { $0.score > $1.score }
        return substringTier.map(\.entry) + fuzzyTier.map(\.entry)
    }

    private static func totalFuzzyScore(tokens: [String], haystack: String) -> Double? {
        var total = 0.0
        for token in tokens {
            guard let score = fuzzyScore(needle: token, haystack: haystack) else { return nil }
            total += score
        }
        return total
    }

    /// Classic fzf-style subsequence scorer. Walks `needle` chars through `haystack`
    /// in order. Returns `nil` if any char can't be found in order. Otherwise returns
    /// a score normalized by haystack length; higher is better. Bonuses for matches
    /// at the start of the string, at word boundaries, and for consecutive matches.
    private static func fuzzyScore(needle: String, haystack: String) -> Double? {
        let foldedNeedle = needle
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let foldedHaystack = haystack
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let query = Array(foldedNeedle)
        let hay = Array(foldedHaystack)
        guard !query.isEmpty, !hay.isEmpty else { return nil }

        var qi = 0
        var score = 0.0
        var lastMatchIndex: Int?

        for hi in 0..<hay.count {
            guard qi < query.count else { break }
            if hay[hi] == query[qi] {
                let bonus: Double
                if hi == 0 {
                    bonus = 2.0             // start of string
                } else if hay[hi - 1].isWhitespace || hay[hi - 1].isPunctuation {
                    bonus = 1.5             // word boundary
                } else if lastMatchIndex == hi - 1 {
                    bonus = 1.0             // consecutive match
                } else {
                    bonus = 0.3             // scattered match
                }
                score += bonus
                lastMatchIndex = hi
                qi += 1
            }
        }

        guard qi == query.count else { return nil }
        return score / Double(hay.count)
    }

    var body: some View {
        Pane {
            NavigationStack(path: $navigationPath) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 20) {
                        PaneHeader(title, subtitle: pretitle, description: subtitle(engine, entries))

                        if entries.isEmpty {
                            emptyState
                        } else {
                            AppCardGrid(items: cardItems)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(32)
                }
                .navigationDestination(for: CatalogEntry.self) { entry in
                    AppDetailsView(entry)
                }
            }
        }
        .navigationTitle(title)
        .task(id: entries.map(\.id)) {
            await loadIcons()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyTitle)
                .font(.headline)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Card mapping

    private var cardItems: [AppCardItem] {
        entries.map { entry in
            AppCardFactory.makeItem(
                for: entry,
                engine: engine,
                iconURL: iconURLs[entry.id],
                onOpenDetails: { navigationPath.append(entry) }
            )
        }
    }

    // MARK: - Icon preload

    private func loadIcons() async {
        for entry in entries where iconURLs[entry.id] == nil {
            if let url = try? await engine.iconFile(for: entry.id) {
                iconURLs[entry.id] = url
            }
        }
    }

    // MARK: - Shared subtitle helpers

    static func countSubtitle(engine: DockyardEngine, entries: [CatalogEntry]) -> String {
        let count = entries.count
        if count == 0 { return "No apps yet" }
        return "\(count) app\(count == 1 ? "" : "s") in this category."
    }
}
