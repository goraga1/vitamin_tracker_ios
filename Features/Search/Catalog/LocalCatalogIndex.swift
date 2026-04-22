import Foundation

/// In-memory inverted index over the bundled catalog. Built once on app
/// startup, then queried for every keystroke. Designed to keep a single
/// `search` call under 30ms for up to 5k products on an iPhone 13.
actor LocalCatalogIndex {
    static let shared = LocalCatalogIndex()

    private var products: [CatalogProduct] = []
    private var tokenIndex: [Substring: [Int]] = [:]
    private var isBuilt = false

    private let minTokenLength = 2
    private let maxProductsPerToken = 2_000

    func build(from products: [CatalogProduct]) async {
        self.products = products
        tokenIndex.removeAll(keepingCapacity: true)

        for (idx, product) in products.enumerated() {
            for token in Self.tokenize(product.searchableText) {
                tokenIndex[token, default: []].append(idx)
            }
        }
        isBuilt = true
    }

    func popularTop(_ limit: Int) -> [CatalogProduct] {
        guard isBuilt else { return [] }
        return products
            .sorted { $0.popularity > $1.popularity }
            .prefix(limit)
            .map { $0 }
    }

    func totalProducts() -> Int { products.count }

    /// AND-semantic token search. Last token is treated as a prefix while the
    /// user is still typing. Scores combine substring, position, brand, and
    /// popularity signals — see `score(for:tokens:query:)`.
    func search(_ query: String, limit: Int = 20) async -> [IndexedMatch] {
        guard isBuilt else { return [] }

        let trimmed = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard trimmed.count >= minTokenLength else { return [] }

        let tokens = Array(Self.tokenize(trimmed))
        guard let firstToken = tokens.first else { return [] }

        var candidate: Set<Int>? = nil

        for (i, token) in tokens.enumerated() {
            let isLast = i == tokens.count - 1
            let hits = isLast ? prefixMatches(for: token) : Set(tokenIndex[token] ?? [])
            if let current = candidate {
                candidate = current.intersection(hits)
            } else {
                candidate = hits
            }
            if candidate?.isEmpty == true { break }
        }

        // If the multi-token intersection failed, fall back to a prefix
        // lookup on just the first token. This catches "vit" → "vitamin d3"
        // where the user's second token hasn't been typed yet.
        if candidate?.isEmpty ?? true {
            candidate = prefixMatches(for: firstToken)
        }

        guard let indices = candidate, !indices.isEmpty else { return [] }

        let scored = indices.map { idx -> IndexedMatch in
            let product = products[idx]
            return IndexedMatch(
                product: product,
                score: score(for: product, tokens: tokens, query: trimmed)
            )
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    private func prefixMatches(for token: Substring) -> Set<Int> {
        if let exact = tokenIndex[token] {
            return Set(exact)
        }
        // Prefix scan — O(unique tokens) but bounded by per-token index sizes.
        // Short-circuits when we already have plenty of candidates.
        var out = Set<Int>()
        for (key, value) in tokenIndex where key.hasPrefix(token) {
            out.formUnion(value)
            if out.count >= maxProductsPerToken { break }
        }
        return out
    }

    private func score(
        for product: CatalogProduct,
        tokens: [Substring],
        query: String
    ) -> Double {
        var score = 0.0
        let text = product.searchableText
        let brandLower = product.brand.lowercased()

        // Full-phrase substring match — strongest positive signal.
        if text.contains(query) {
            score += 0.4
            if text.hasPrefix(query) { score += 0.1 }
        }

        // Brand prefix — user typing the brand first is a very common pattern.
        if let first = tokens.first, brandLower.hasPrefix(first) {
            score += 0.2
        }

        // Token position: earlier positions win. Score decays with offset.
        if let first = tokens.first,
           let range = text.range(of: first) {
            let offset = text.distance(from: text.startIndex, to: range.lowerBound)
            let normalized = max(0.0, 1.0 - Double(offset) / 60.0)
            score += 0.1 * normalized
        }

        // Popularity is already 0…100.
        score += 0.2 * (Double(product.popularity) / 100.0)

        // Shorter names feel more "canonical" — cap the bonus.
        let nameLen = product.name.count
        if nameLen <= 20 { score += 0.1 }
        else if nameLen <= 35 { score += 0.05 }

        return min(score, 1.0)
    }

    // MARK: - Tokenization

    private static let tokenBreaks = CharacterSet.alphanumerics.inverted

    /// Splits a precomputed searchable string into non-empty alphanumeric
    /// tokens. Returns substrings into the caller's buffer to avoid
    /// allocations on the hot path.
    static func tokenize(_ s: String) -> [Substring] {
        // searchableText is already lowercased + punctuation-stripped by the
        // crawler, but we still handle whitespace / hyphens defensively.
        let mapped = s.unicodeScalars.map { scalar -> Character in
            tokenBreaks.contains(scalar) ? " " : Character(scalar)
        }
        let cleaned = String(mapped)
        return cleaned.split(separator: " ").filter { $0.count >= 2 }
    }
}

struct IndexedMatch: Hashable, Sendable {
    let product: CatalogProduct
    let score: Double
}
