import Foundation
import SwiftData

/// Local cache of DSLD products the user has seen. Populated lazily by
/// `DSLDClient` in the scan flow and by `DSLDSearchFallback` in the search
/// flow. Lets search work offline for products the user already encountered.
///
/// `searchableText` is a precomputed, lowercased concatenation of
/// `brand + productName + ingredient tokens` so SwiftData can use a cheap
/// `localizedStandardContains` predicate without touching `cachedPayload`.
@Model
final class SupplementCatalog {
    @Attribute(.unique) var dsldId: String
    var brand: String
    var productName: String
    var cachedPayload: Data
    var lastFetchedAt: Date
    var searchableText: String

    init(
        dsldId: String,
        brand: String,
        productName: String,
        cachedPayload: Data,
        searchableText: String? = nil
    ) {
        self.dsldId = dsldId
        self.brand = brand
        self.productName = productName
        self.cachedPayload = cachedPayload
        self.lastFetchedAt = .now
        self.searchableText = searchableText
            ?? Self.computeSearchableText(brand: brand, productName: productName)
    }

    /// Build the search-index string used by the SwiftData predicate. Kept as
    /// a static helper so both `init` and the search-fallback insert path can
    /// share identical normalization.
    static func computeSearchableText(brand: String, productName: String) -> String {
        "\(brand) \(productName)"
            .lowercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
