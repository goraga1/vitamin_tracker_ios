import Foundation

/// Pure helpers that turn `CatalogProduct` values into display-ready
/// `SearchResult`s. Kept outside of `CatalogSearcher` so the merger/tests
/// can use them without spinning up a coordinator.
enum SearchResultFactory {
    static func fromBundled(_ match: IndexedMatch) -> SearchResult {
        let p = match.product
        return SearchResult(
            id: "bundled-\(p.id)",
            brand: p.brand,
            name: p.name,
            form: p.form,
            keyIngredients: p.keyIngredients,
            source: .bundled,
            relevanceScore: match.score,
            enrichmentKey: .dsld(id: p.id)
        )
    }

    static func fromCachedCatalog(
        dsldId: String,
        brand: String,
        productName: String,
        relevance: Double
    ) -> SearchResult {
        SearchResult(
            id: "cached-\(dsldId)",
            brand: brand,
            name: productName,
            form: .other,  // cache payload carries full detail; row UI doesn't need form
            keyIngredients: [],
            source: .swiftDataCache,
            relevanceScore: relevance,
            enrichmentKey: .dsld(id: dsldId)
        )
    }

    static func fromDSLDProduct(_ product: DSLDProduct, relevance: Double) -> SearchResult {
        SearchResult(
            id: "dsld-\(product.dsldId)",
            brand: product.brand,
            name: product.productName,
            form: .other,
            keyIngredients: [],
            source: .dsldLive,
            relevanceScore: relevance,
            enrichmentKey: .dsld(id: product.dsldId)
        )
    }
}
