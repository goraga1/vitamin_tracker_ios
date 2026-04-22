import XCTest
@testable import VitaminTracker

final class CatalogProductDecodingTests: XCTestCase {

    func testDecodesProductionSchema() throws {
        let json = """
        {
          "id": "123",
          "brand": "Nature Made",
          "name": "Vitamin D3 2000 IU",
          "form": "softgel",
          "servingSize": { "value": 1, "unit": "Softgel" },
          "keyIngredients": [
            { "nutrientKey": "vitamin_d", "amount": 50, "unit": "mcg" }
          ],
          "searchableText": "nature made vitamin d3 2000 iu softgel",
          "popularity": 85
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CatalogProduct.self, from: json)
        XCTAssertEqual(decoded.id, "123")
        XCTAssertEqual(decoded.brand, "Nature Made")
        XCTAssertEqual(decoded.form, .softgel)
        XCTAssertEqual(decoded.keyIngredients.first?.nutrientKey, "vitamin_d")
        XCTAssertEqual(decoded.popularity, 85)
    }

    func testUnknownFormFallsBackToOther() throws {
        let json = """
        {
          "id": "x",
          "brand": "Brand",
          "name": "Thing",
          "form": "exotic_form_not_in_enum",
          "keyIngredients": [],
          "searchableText": "brand thing",
          "popularity": 10
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CatalogProduct.self, from: json)
        XCTAssertEqual(decoded.form, .other)
    }

    func testBundledCatalogFileDecodes() throws {
        guard let url = Bundle.main.url(forResource: "catalog_v1", withExtension: "json") else {
            throw XCTSkip("catalog_v1.json not in test bundle")
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)
        XCTAssertGreaterThan(file.products.count, 0)
        XCTAssertEqual(file.products.count, file.totalProducts)
        // Every product must have non-empty searchableText — the index builder relies on this.
        for p in file.products {
            XCTAssertFalse(p.searchableText.isEmpty, "Empty searchableText in \(p.id)")
        }
    }
}
