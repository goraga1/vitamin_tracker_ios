import Foundation
import SwiftData

/// Seed data mirrors the `STACK` array in `Shared.jsx` so the iOS build
/// looks identical to the prototype. `seedSupplementsIfEmpty` is called
/// from `OnboardingFlow` after A8 (or directly from previews); the profile
/// is created during onboarding, not here.
enum MockData {
    struct Row {
        let id: String
        let brand: String
        let name: String
        let dose: String
        let tint: UInt32
        let accent: UInt32
        let time: TimeOfDay
        let active: Bool
        let ingredients: [(String, Double, String)] // (key, amount, unit)
        let form: SupplementForm
        let servingSize: Double
        let servingUnit: String
    }

    static let rows: [Row] = [
        Row(id: "vitd",  brand: "Thorne",               name: "Vitamin D3",           dose: "5,000 IU", tint: 0xF3E5C6, accent: 0xC49A48, time: .morning, active: true,  ingredients: [("vitamin_d", 125, "µg")], form: .capsule, servingSize: 1, servingUnit: "capsule"),
        Row(id: "ome3",  brand: "Nordic Naturals",      name: "Omega-3",              dose: "1,280 mg", tint: 0xE5EDD9, accent: 0x7C9658, time: .morning, active: true,  ingredients: [("epa", 650, "mg"), ("dha", 450, "mg")], form: .softgel, servingSize: 2, servingUnit: "softgels"),
        Row(id: "mag",   brand: "Pure Encapsulations", name: "Magnesium Glycinate",  dose: "240 mg",   tint: 0xE2E6EE, accent: 0x6F7C96, time: .evening, active: true,  ingredients: [("magnesium", 240, "mg")], form: .capsule, servingSize: 2, servingUnit: "capsules"),
        Row(id: "multi", brand: "Ritual",               name: "Women's Multi",        dose: "2 caps",   tint: 0xF8E4E0, accent: 0xC07A6B, time: .morning, active: true,  ingredients: [("vitamin_c", 80, "mg"), ("iron", 8, "mg"), ("folate", 1000, "µg"), ("vitamin_b12", 8, "µg")], form: .capsule, servingSize: 2, servingUnit: "capsules"),
        Row(id: "zinc",  brand: "Solgar",               name: "Zinc Picolinate",      dose: "22 mg",    tint: 0xE7E0D2, accent: 0xA08753, time: .midday,  active: true,  ingredients: [("zinc", 22, "mg")], form: .capsule, servingSize: 1, servingUnit: "capsule"),
        Row(id: "crea",  brand: "Thorne",               name: "Creatine Mono",        dose: "5 g",      tint: 0xDDE6E4, accent: 0x6D8884, time: .midday,  active: true,  ingredients: [("creatine", 5, "g")], form: .powder, servingSize: 1, servingUnit: "scoop"),
        Row(id: "ash",   brand: "Gaia Herbs",           name: "Ashwagandha",          dose: "600 mg",   tint: 0xE8DCC9, accent: 0x9A7A4E, time: .night,   active: true,  ingredients: [("ashwagandha", 600, "mg")], form: .capsule, servingSize: 1, servingUnit: "capsule"),
        Row(id: "prob",  brand: "Seed",                 name: "Probiotic",            dose: "2 caps",   tint: 0xD9E3DE, accent: 0x6B8578, time: .morning, active: false, ingredients: [("probiotic_cfu", 53.6, "B CFU")], form: .capsule, servingSize: 2, servingUnit: "capsules"),
    ]

    /// Inserts the 8 seed supplements if the store has none.
    static func seedSupplementsIfEmpty(context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<Supplement>())
        guard existing?.isEmpty ?? true else { return }

        for row in rows {
            let supp = Supplement(
                brand: row.brand,
                productName: row.name,
                form: row.form,
                servingSize: row.servingSize,
                servingUnit: row.servingUnit,
                tintHex: String(format: "#%06X", row.tint),
                accentHex: String(format: "#%06X", row.accent),
                isPaused: !row.active
            )
            supp.ingredients = row.ingredients.map {
                Ingredient(nutrientKey: $0.0, amount: $0.1, unit: $0.2)
            }

            let cal = Calendar.current
            let specific = switch row.time {
            case .morning: cal.date(from: DateComponents(hour: 7,  minute: 30))
            case .midday:  cal.date(from: DateComponents(hour: 12, minute: 30))
            case .evening: cal.date(from: DateComponents(hour: 19, minute: 0))
            case .night:   cal.date(from: DateComponents(hour: 22, minute: 0))
            case .custom:  nil
            }
            supp.schedules = [Schedule(timeOfDay: row.time, specificTime: specific)]
            context.insert(supp)
        }

        try? context.save()
    }

    /// Creates the default user profile with a 14-day streak baseline, if
    /// none exists.
    @discardableResult
    static func ensureProfile(
        context: ModelContext,
        onboardingCompleted: Bool = true,
        streakDays: Int = 14
    ) -> UserProfile {
        if let existing = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            return existing
        }
        let profile = UserProfile(
            displayName: "Maya",
            streakDays: streakDays,
            onboardingCompleted: onboardingCompleted
        )
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// In-memory container for `#Preview`. Defaults to a fully-seeded store
    /// so screens render realistically; toggle the flags to preview empty
    /// states or the onboarding flow.
    @MainActor static func previewContainer(
        seedSupplements: Bool = true,
        seedProfile: Bool = true
    ) -> ModelContainer {
        let schema = Schema([
            Supplement.self, Ingredient.self, Schedule.self,
            IntakeLog.self, UserProfile.self, SupplementCatalog.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        if seedSupplements { seedSupplementsIfEmpty(context: container.mainContext) }
        if seedProfile     { ensureProfile(context: container.mainContext) }
        return container
    }
}
