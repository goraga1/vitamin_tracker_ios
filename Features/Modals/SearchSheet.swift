import SwiftUI
import SwiftData

/// Thin adapter between the old entry point (`AddSupplementSheet` selection)
/// and the new hybrid `SearchView`. Responsible for taking a `SearchResult`
/// selection and turning it into a real `Supplement` row in SwiftData.
///
/// Full DSLD label enrichment (ingredients, serving size, etc.) lands in a
/// follow-up — for now the inserted `Supplement` has the same safe defaults
/// the previous hardcoded screen used.
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var addedName: String?
    @State private var showManualAdd: Bool = false
    @State private var isEnriching: Bool = false

    private let enricher = SelectionEnricher()

    var body: some View {
        SearchView(
            onSelect: handleSelect,
            onManualAdd: { showManualAdd = true }
        )
        .sheet(isPresented: $showManualAdd) {
            ManualAddForm { supp in
                addedName = supp.productName
            }
        }
        .alert(
            "Added to your stack",
            isPresented: Binding(
                get: { addedName != nil },
                set: { if !$0 { addedName = nil } }
            ),
            actions: { Button("OK", role: .cancel) { dismiss() } },
            message: { Text(addedName ?? "") }
        )
    }

    private func handleSelect(_ result: SearchResult) {
        // Insert the skeleton row immediately so the UI feels instant. If
        // network enrichment succeeds we fill in the serving size + full
        // ingredient list; if it fails we're still left with a usable row.
        let tint = PaletteRotation.tint(for: result.id)
        let accent = PaletteRotation.accent(for: result.id)

        let supp = Supplement(
            brand: result.brand,
            productName: result.name,
            form: result.form == .other ? .capsule : result.form,
            servingSize: 1,
            servingUnit: servingUnit(for: result.form),
            tintHex: String(format: "#%06X", tint),
            accentHex: String(format: "#%06X", accent)
        )
        supp.ingredients = result.keyIngredients.map { ing in
            Ingredient(nutrientKey: ing.nutrientKey, amount: ing.amount, unit: ing.unit)
        }
        if case .dsld(let id) = result.enrichmentKey {
            supp.dsldId = id
        }
        let time = Calendar.current.date(
            bySettingHour: 8, minute: 0, second: 0, of: .now
        ) ?? .now
        supp.schedules = [Schedule(timeOfDay: .morning, specificTime: time)]
        context.insert(supp)
        try? context.save()
        addedName = result.name

        // Kick off async enrichment. When it returns we mutate the same
        // object on the main actor. SwiftData publishes the changes, Today /
        // Stack views redraw automatically.
        let suppID = supp.id
        Task { @MainActor in
            isEnriching = true
            defer { isEnriching = false }
            let enriched = await enricher.enrich(result)
            apply(enriched, to: suppID)
        }
    }

    private func apply(_ enriched: EnrichedSelection, to supplementID: UUID) {
        let descriptor = FetchDescriptor<Supplement>(
            predicate: #Predicate<Supplement> { $0.id == supplementID }
        )
        guard let supp = (try? context.fetch(descriptor))?.first else { return }

        supp.form = enriched.form
        if let size = enriched.servingSize { supp.servingSize = size }
        if let unit = enriched.servingUnit, !unit.isEmpty { supp.servingUnit = unit }
        if !enriched.ingredients.isEmpty {
            supp.ingredients = enriched.ingredients.map { e in
                Ingredient(
                    nutrientKey: e.nutrientKey,
                    amount: e.amount,
                    unit: e.unit,
                    form: e.form
                )
            }
        }
        supp.updatedAt = .now
        try? context.save()
    }

    private func handleManualAdd() {
        // Hand-off to the manual entry form is implemented in a separate
        // task. For now we bail back to the caller so they can decide.
        dismiss()
    }

    private func servingUnit(for form: SupplementForm) -> String {
        switch form {
        case .tablet: "tab"
        case .capsule: "cap"
        case .softgel: "softgel"
        case .liquid: "ml"
        case .powder: "scoop"
        case .gummy: "gummy"
        case .lozenge: "lozenge"
        case .other: "cap"
        }
    }
}

/// Deterministic palette assignment so repeat searches for the same product
/// land on the same colors. Pure function of the product id; no global state.
private enum PaletteRotation {
    private static let tints: [UInt32] = [
        0xE2E6EE, 0xF3E5C6, 0xE5EDD9, 0xF8E4E0, 0xE7E2F3, 0xDDEEF2,
    ]
    private static let accents: [UInt32] = [
        0x6F7C96, 0xC49A48, 0x7C9658, 0xC07A6B, 0x7F6EB3, 0x4F8796,
    ]

    static func tint(for id: String) -> UInt32 {
        tints[index(for: id, modulo: tints.count)]
    }

    static func accent(for id: String) -> UInt32 {
        accents[index(for: id, modulo: accents.count)]
    }

    private static func index(for id: String, modulo: Int) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % UInt64(modulo))
    }
}

#Preview { SearchSheet() }
