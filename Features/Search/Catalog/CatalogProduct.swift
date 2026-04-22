import Foundation

/// A single product row from the bundled catalog JSON. Matches the schema
/// produced by `tools/dsld-crawler/src/exporter.ts`.
struct CatalogProduct: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let brand: String
    let name: String
    let form: SupplementForm
    let servingSize: ServingSize?
    let keyIngredients: [CatalogIngredient]
    let searchableText: String
    let popularity: Int

    struct ServingSize: Codable, Hashable, Sendable {
        let value: Double
        let unit: String
    }

    // Decode leniency — bundled JSON may contain `form` values outside the
    // enum if the crawler evolves faster than the app. Unknown forms collapse
    // to `.other` rather than failing the whole load.
    private enum CodingKeys: String, CodingKey {
        case id, brand, name, form, servingSize, keyIngredients, searchableText, popularity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.brand = try c.decode(String.self, forKey: .brand)
        self.name = try c.decode(String.self, forKey: .name)
        let rawForm = try c.decode(String.self, forKey: .form)
        self.form = SupplementForm(rawValue: rawForm) ?? .other
        self.servingSize = try c.decodeIfPresent(ServingSize.self, forKey: .servingSize)
        self.keyIngredients = try c.decodeIfPresent([CatalogIngredient].self, forKey: .keyIngredients) ?? []
        self.searchableText = try c.decode(String.self, forKey: .searchableText)
        self.popularity = try c.decodeIfPresent(Int.self, forKey: .popularity) ?? 0
    }

    init(
        id: String,
        brand: String,
        name: String,
        form: SupplementForm,
        servingSize: ServingSize? = nil,
        keyIngredients: [CatalogIngredient] = [],
        searchableText: String,
        popularity: Int
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.form = form
        self.servingSize = servingSize
        self.keyIngredients = keyIngredients
        self.searchableText = searchableText
        self.popularity = popularity
    }
}

struct CatalogIngredient: Codable, Hashable, Sendable {
    let nutrientKey: String
    let amount: Double
    let unit: String
}

/// Top-level catalog file envelope. Only `products` is load-critical; the
/// rest is metadata useful for support / debugging.
struct CatalogFile: Codable, Sendable {
    let version: String
    let generatedAt: String
    let totalProducts: Int
    let sourceRevision: String?
    let products: [CatalogProduct]
}
