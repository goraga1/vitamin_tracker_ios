import Foundation
import SwiftData

/// Local cache of DSLD products the user has seen. Populated lazily by
/// `DSLDClient` in a later phase; lets search work offline for products the
/// user already encountered.
@Model
final class SupplementCatalog {
    @Attribute(.unique) var dsldId: String
    var brand: String
    var productName: String
    var cachedPayload: Data
    var lastFetchedAt: Date

    init(dsldId: String, brand: String, productName: String, cachedPayload: Data) {
        self.dsldId = dsldId
        self.brand = brand
        self.productName = productName
        self.cachedPayload = cachedPayload
        self.lastFetchedAt = .now
    }
}
