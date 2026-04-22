import XCTest
@testable import VitaminTracker

final class SearchResultMergerTests: XCTestCase {

    private func bundled(_ id: String, _ brand: String, _ name: String, score: Double = 0.8) -> IndexedMatch {
        IndexedMatch(
            product: CatalogProduct(
                id: id,
                brand: brand,
                name: name,
                form: .capsule,
                servingSize: nil,
                keyIngredients: [],
                searchableText: "\(brand) \(name)".lowercased(),
                popularity: 50
            ),
            score: score
        )
    }

    private func cached(_ id: String, _ brand: String, _ name: String) -> SearchResult {
        SearchResultFactory.fromCachedCatalog(
            dsldId: id,
            brand: brand,
            productName: name,
            relevance: 0.7
        )
    }

    private func live(_ id: String, _ brand: String, _ name: String) -> SearchResult {
        SearchResultFactory.fromDSLDProduct(
            DSLDProduct(dsldId: id, brand: brand, productName: name, thumbnail: nil),
            relevance: 0.6
        )
    }

    func testBundledResultsTakePrecedenceOverCache() {
        let merger = SearchResultMerger()
        let merged = merger.merge(
            local: [bundled("b1", "Thorne", "Magnesium")],
            cached: [cached("c1", "Thorne", "Magnesium")]
        )
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.source, .bundled)
    }

    func testRemoteIsAppendedWithoutReplacingExisting() {
        let merger = SearchResultMerger()
        let existing = [
            SearchResultFactory.fromBundled(bundled("b1", "Thorne", "Magnesium"))
        ]
        let remote = [
            live("r1", "Thorne", "Magnesium"),       // duplicate — should be dropped
            live("r2", "Solgar", "Vitamin D3"),      // new — should be kept
        ]
        let merged = merger.merge(existing: existing, remote: remote)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first?.source, .bundled)
        XCTAssertEqual(merged.last?.source, .dsldLive)
    }

    func testSortingPutsBundledBeforeCacheBeforeLive() {
        let merger = SearchResultMerger()
        let merged = merger.merge(
            existing: [
                live("x", "Brand X", "Product X"),
                cached("y", "Brand Y", "Product Y"),
                SearchResultFactory.fromBundled(bundled("z", "Brand Z", "Product Z")),
            ],
            remote: []
        )
        XCTAssertEqual(merged.map(\.source), [.bundled, .swiftDataCache, .dsldLive])
    }

    func testDedupKeyIsCaseInsensitive() {
        let merger = SearchResultMerger()
        let merged = merger.merge(
            local: [bundled("b1", "Thorne", "Magnesium Glycinate")],
            cached: [cached("c1", "THORNE", "magnesium glycinate")]
        )
        XCTAssertEqual(merged.count, 1)
    }

    func testEmptyInputsReturnEmpty() {
        let merger = SearchResultMerger()
        XCTAssertTrue(merger.merge(local: [], cached: []).isEmpty)
        XCTAssertTrue(merger.merge(existing: [], remote: []).isEmpty)
    }
}
