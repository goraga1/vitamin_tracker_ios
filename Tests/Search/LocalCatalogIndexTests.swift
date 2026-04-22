import XCTest
@testable import VitaminTracker

final class LocalCatalogIndexTests: XCTestCase {

    // MARK: - Helpers

    private func product(
        id: String,
        brand: String,
        name: String,
        searchableText: String? = nil,
        popularity: Int = 50,
        form: SupplementForm = .capsule
    ) -> CatalogProduct {
        CatalogProduct(
            id: id,
            brand: brand,
            name: name,
            form: form,
            servingSize: nil,
            keyIngredients: [],
            searchableText: searchableText ?? "\(brand) \(name)".lowercased(),
            popularity: popularity
        )
    }

    private func makeIndex(_ products: [CatalogProduct]) async -> LocalCatalogIndex {
        let index = LocalCatalogIndex()
        await index.build(from: products)
        return index
    }

    // MARK: - Tokenization

    func testTokenizeSplitsOnPunctuationAndLowercases() {
        let tokens = LocalCatalogIndex.tokenize("Nature Made, Vitamin D3 2000 IU!")
        XCTAssertEqual(tokens.map(String.init), ["nature", "made", "vitamin", "d3", "2000", "iu"])
    }

    func testTokenizeDropsSingleCharacters() {
        let tokens = LocalCatalogIndex.tokenize("a b c magnesium")
        XCTAssertEqual(tokens.map(String.init), ["magnesium"])
    }

    // MARK: - Search semantics

    func testSingleTokenExactMatch() async {
        let index = await makeIndex([
            product(id: "1", brand: "Thorne", name: "Magnesium"),
            product(id: "2", brand: "Nordic Naturals", name: "Omega"),
        ])
        let results = await index.search("magnesium")
        XCTAssertEqual(results.map(\.product.id), ["1"])
    }

    func testAndSemanticsRequiresAllTokens() async {
        let index = await makeIndex([
            product(id: "1", brand: "Thorne", name: "Magnesium Glycinate"),
            product(id: "2", brand: "NOW", name: "Magnesium Citrate"),
            product(id: "3", brand: "Ritual", name: "Essential for Women"),
        ])
        let results = await index.search("thorne magnesium")
        XCTAssertEqual(results.map(\.product.id), ["1"])
    }

    func testLastTokenTreatedAsPrefix() async {
        // User is mid-typing "magnesium"
        let index = await makeIndex([
            product(id: "1", brand: "Thorne", name: "Magnesium Glycinate"),
            product(id: "2", brand: "NOW", name: "Multivitamin"),
        ])
        let results = await index.search("magnes")
        XCTAssertEqual(results.map(\.product.id), ["1"])
    }

    func testFirstTokenPrefixFallbackWhenIntersectionEmpty() async {
        // "vita" doesn't exist as a whole token in either row — both rows
        // should still surface via prefix scan.
        let index = await makeIndex([
            product(id: "1", brand: "Nature Made", name: "Vitamin D3"),
            product(id: "2", brand: "NOW", name: "Vitamin C"),
            product(id: "3", brand: "Thorne", name: "Magnesium"),
        ])
        let results = await index.search("vita")
        let ids = Set(results.map(\.product.id))
        XCTAssertTrue(ids.contains("1"))
        XCTAssertTrue(ids.contains("2"))
        XCTAssertFalse(ids.contains("3"))
    }

    func testEmptyQueryReturnsNothing() async {
        let index = await makeIndex([product(id: "1", brand: "Thorne", name: "Magnesium")])
        let results = await index.search("")
        XCTAssertTrue(results.isEmpty)
    }

    func testOneCharacterQueryReturnsNothing() async {
        let index = await makeIndex([product(id: "1", brand: "Thorne", name: "Magnesium")])
        let results = await index.search("a")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Scoring

    func testHigherPopularityRanksHigher() async {
        let index = await makeIndex([
            product(id: "low", brand: "Thorne", name: "Magnesium", popularity: 10),
            product(id: "high", brand: "Thorne", name: "Magnesium Glycinate", popularity: 95),
        ])
        let results = await index.search("magnesium")
        XCTAssertEqual(results.first?.product.id, "high")
    }

    func testPopularTopReturnsByPopularityDescending() async {
        let index = await makeIndex([
            product(id: "a", brand: "A", name: "x", popularity: 30),
            product(id: "b", brand: "B", name: "y", popularity: 90),
            product(id: "c", brand: "C", name: "z", popularity: 60),
        ])
        let top = await index.popularTop(2)
        XCTAssertEqual(top.map(\.id), ["b", "c"])
    }
}
