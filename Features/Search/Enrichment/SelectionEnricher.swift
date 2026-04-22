import Foundation

/// Fills in the full ingredient / serving detail behind a search result.
/// Search rows are intentionally lightweight — `keyIngredients` is empty for
/// bundled catalog entries (the fast crawler skips `/label` fetches). When
/// the user actually picks a product we fetch its label from DSLD once,
/// map the rows to the app's nutrient dictionary, and return an enrichment
/// ready to attach to a new `Supplement`.
///
/// All error paths collapse to an empty enrichment — the caller can still
/// save the bare brand/name row so the user's flow is never blocked by
/// network failure.
struct SelectionEnricher {
    let client: DSLDClient
    let dictionary: NutrientDictionary

    init(
        client: DSLDClient = .shared,
        dictionary: NutrientDictionary = .shared
    ) {
        self.client = client
        self.dictionary = dictionary
    }

    func enrich(_ result: SearchResult) async -> EnrichedSelection {
        guard case .dsld(let id) = result.enrichmentKey else {
            return EnrichedSelection(form: result.form, servingSize: nil, servingUnit: nil, ingredients: [])
        }
        guard let label = await client.label(id) else {
            return EnrichedSelection(form: result.form, servingSize: nil, servingUnit: nil, ingredients: [])
        }

        let form = inferForm(from: label, fallback: result.form)
        let servingSize = label.servingSizes.first?.quantity
        let servingUnit = label.servingSizes.first?.unit

        var seen = Set<String>()
        let ingredients = label.ingredientRows.compactMap { row -> EnrichedIngredient? in
            guard let match = dictionary.lookup(row.name),
                  let amount = row.quantity,
                  seen.insert(match.key).inserted
            else { return nil }
            return EnrichedIngredient(
                nutrientKey: match.key,
                amount: amount,
                unit: (row.unit ?? match.unit).lowercased(),
                form: row.forms?.first
            )
        }

        return EnrichedSelection(
            form: form,
            servingSize: servingSize,
            servingUnit: servingUnit,
            ingredients: ingredients
        )
    }

    private func inferForm(from label: DSLDLabel, fallback: SupplementForm) -> SupplementForm {
        let haystack = [label.productName, label.physicalState ?? ""]
            .joined(separator: " ")
            .lowercased()
        if haystack.contains("softgel") { return .softgel }
        if haystack.contains("gummy") || haystack.contains("gummies") { return .gummy }
        if haystack.contains("liquid") || haystack.contains("drops") || haystack.contains("tincture") { return .liquid }
        if haystack.contains("powder") { return .powder }
        if haystack.contains("lozenge") || haystack.contains("troche") { return .lozenge }
        if haystack.contains("tablet") || haystack.contains("caplet") { return .tablet }
        if haystack.contains("capsule") || haystack.contains("vcap") { return .capsule }
        return fallback
    }
}

struct EnrichedSelection {
    let form: SupplementForm
    let servingSize: Double?
    let servingUnit: String?
    let ingredients: [EnrichedIngredient]
}

struct EnrichedIngredient {
    let nutrientKey: String
    let amount: Double
    let unit: String
    let form: String?
}
