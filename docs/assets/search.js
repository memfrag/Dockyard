// Tokenized + fuzzy subsequence scorer.
// Mirrors the Swift CatalogPane.rank logic: locale-insensitive substring match
// is tier 1; subsequence match (fzf-style) is tier 2; both ranked by a
// positional/word-boundary scoring.

function fold(str) {
    // Case-fold + strip diacritics. Matches Foundation's
    // .folding(options: [.caseInsensitive, .diacriticInsensitive]).
    return str.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

function searchTokens(query) {
    const trimmed = query.trim();
    if (!trimmed) return null;
    return trimmed.split(/\s+/);
}

// Returns a score in [0, +inf) when `needle` is a subsequence of `haystack`,
// or null when any char of `needle` can't be found in order.
function fuzzyScore(needle, haystack) {
    const n = fold(needle);
    const h = fold(haystack);
    if (!n || !h) return null;

    let qi = 0;
    let score = 0;
    let lastMatch = -1;

    for (let hi = 0; hi < h.length; hi++) {
        if (qi >= n.length) break;
        if (h[hi] === n[qi]) {
            let bonus;
            if (hi === 0) {
                bonus = 2.0; // start of string
            } else {
                const prev = h[hi - 1];
                if (/\s|[.,:;!?()\[\]{}/\\_-]/.test(prev)) {
                    bonus = 1.5; // word boundary
                } else if (lastMatch === hi - 1) {
                    bonus = 1.0; // consecutive match
                } else {
                    bonus = 0.3; // scattered match
                }
            }
            score += bonus;
            lastMatch = hi;
            qi++;
        }
    }

    if (qi !== n.length) return null;
    return score / h.length;
}

function totalFuzzyScore(tokens, haystack) {
    let total = 0;
    for (const token of tokens) {
        const s = fuzzyScore(token, haystack);
        if (s === null) return null;
        total += s;
    }
    return total;
}

function haystackFor(entry) {
    return [entry.displayName || "", entry.summary || "", entry.category || ""].join(" ");
}

/**
 * Two-tier ranking:
 *   1. Entries where every token has a locale-insensitive substring match (tier 1),
 *      ordered by combined fuzzy score.
 *   2. Entries where every token is at least a subsequence match (tier 2),
 *      ordered by combined fuzzy score. Shown after tier 1.
 * Entries that fail to match at least one token on both tiers are excluded.
 *
 * @param {Array} entries - Array of CatalogEntry-shaped objects.
 * @param {string} query  - Free-text query string.
 * @returns {Array}         Filtered + sorted entries. Unchanged reference if query is empty.
 */
export function rank(entries, query) {
    const tokens = searchTokens(query);
    if (!tokens) return entries;

    const tier1 = [];
    const tier2 = [];

    for (const entry of entries) {
        const haystack = haystackFor(entry);
        const folded = fold(haystack);

        const hasSubstringForAll = tokens.every(tok => folded.includes(fold(tok)));
        const score = totalFuzzyScore(tokens, haystack);
        if (score === null) continue;

        if (hasSubstringForAll) {
            tier1.push({ entry, score });
        } else {
            tier2.push({ entry, score });
        }
    }

    tier1.sort((a, b) => b.score - a.score);
    tier2.sort((a, b) => b.score - a.score);
    return [...tier1.map(x => x.entry), ...tier2.map(x => x.entry)];
}
