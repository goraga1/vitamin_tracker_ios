import Foundation
import SwiftData

@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var nutrientKey: String
    var amount: Double
    var unit: String
    var form: String?

    init(id: UUID = UUID(), nutrientKey: String, amount: Double, unit: String, form: String? = nil) {
        self.id = id
        self.nutrientKey = nutrientKey
        self.amount = amount
        self.unit = unit
        self.form = form
    }
}
