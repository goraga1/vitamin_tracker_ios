import Foundation
import SwiftData

@Model
final class Supplement {
    @Attribute(.unique) var id: UUID
    var dsldId: String?
    var brand: String
    var productName: String
    var form: SupplementForm
    var servingSize: Double
    var servingUnit: String
    var photoLocalPath: String?
    var barcode: String?
    var notes: String?
    var costPerBottle: Decimal?
    var servingsPerBottle: Int?
    var purchasedAt: Date?
    var isPaused: Bool = false
    var pausedUntil: Date?
    var createdAt: Date
    var updatedAt: Date

    // Visual tokens from the prototype — in production these come from the label photo
    // or a palette extracted from DSLD. For mock data we set them explicitly.
    var tintHex: String
    var accentHex: String

    @Relationship(deleteRule: .cascade) var ingredients: [Ingredient] = []
    @Relationship(deleteRule: .cascade) var schedules: [Schedule] = []
    @Relationship(inverse: \IntakeLog.supplement) var logs: [IntakeLog] = []

    init(
        id: UUID = UUID(),
        brand: String,
        productName: String,
        form: SupplementForm,
        servingSize: Double,
        servingUnit: String,
        tintHex: String,
        accentHex: String,
        notes: String? = nil,
        isPaused: Bool = false
    ) {
        self.id = id
        self.brand = brand
        self.productName = productName
        self.form = form
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.tintHex = tintHex
        self.accentHex = accentHex
        self.notes = notes
        self.isPaused = isPaused
        self.createdAt = .now
        self.updatedAt = .now
    }
}
