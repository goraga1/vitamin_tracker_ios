import Foundation
import SwiftData

/// Searches previously-fetched DSLD products cached in SwiftData. Only runs
/// against the precomputed `searchableText` column — never decodes
/// `cachedPayload` during the search pass.
struct SwiftDataCatalogSearcher {
    let modelContext: ModelContext

    func search(_ rawQuery: String, limit: Int) async -> [SearchResult] {
        let query = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard query.count >= 2 else { return [] }

        var descriptor = FetchDescriptor<SupplementCatalog>(
            predicate: #Predicate<SupplementCatalog> { row in
                row.searchableText.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.lastFetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let rows: [SupplementCatalog]
        do {
            rows = try modelContext.fetch(descriptor)
        } catch {
            print("[SwiftDataCatalogSearcher] fetch failed: \(error)")
            return []
        }

        // Simple recency-ranked relevance: most recently fetched row scores
        // highest. Good enough since the cache is typically small (<200 rows
        // for active users) and real relevance work happens in the merger.
        return rows.enumerated().map { idx, row in
            let relevance = max(0.0, 1.0 - Double(idx) * 0.05)
            return SearchResultFactory.fromCachedCatalog(
                dsldId: row.dsldId,
                brand: row.brand,
                productName: row.productName,
                relevance: relevance
            )
        }
    }

    /// Upsert a DSLD hit into the cache so subsequent searches for the same
    /// product work offline. Idempotent: existing rows are refreshed in place.
    func upsert(_ product: DSLDProduct, payload: Data) {
        let dsldId = product.dsldId
        let descriptor = FetchDescriptor<SupplementCatalog>(
            predicate: #Predicate<SupplementCatalog> { $0.dsldId == dsldId }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first

        if let existing {
            existing.brand = product.brand
            existing.productName = product.productName
            existing.cachedPayload = payload
            existing.lastFetchedAt = .now
            existing.searchableText = SupplementCatalog.computeSearchableText(
                brand: product.brand,
                productName: product.productName
            )
        } else {
            let row = SupplementCatalog(
                dsldId: product.dsldId,
                brand: product.brand,
                productName: product.productName,
                cachedPayload: payload
            )
            modelContext.insert(row)
        }
        try? modelContext.save()
    }
}
