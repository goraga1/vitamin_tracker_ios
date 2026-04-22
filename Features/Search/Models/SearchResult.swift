import Foundation

/// A single row rendered in the hybrid search list. Unifies the three
/// underlying sources (bundled JSON, SwiftData cache, live DSLD) behind one
/// consumer-facing shape so the UI doesn't branch on source.
struct SearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let brand: String
    let name: String
    let form: SupplementForm
    let keyIngredients: [CatalogIngredient]
    let source: SearchSource
    let relevanceScore: Double
    let enrichmentKey: EnrichmentKey
}

enum SearchSource: Hashable, Sendable {
    case bundled
    case swiftDataCache
    case dsldLive

    var priority: Int {
        switch self {
        case .bundled: 0
        case .swiftDataCache: 1
        case .dsldLive: 2
        }
    }
}

/// Describes how to fetch the full product data if the user selects this
/// result. Search rows are intentionally lightweight — the expensive
/// per-product label fetch is deferred until after selection.
enum EnrichmentKey: Hashable, Sendable {
    case dsld(id: String)
    case swiftData(uuid: UUID)
    case none
}
