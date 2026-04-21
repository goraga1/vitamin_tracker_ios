import Foundation
import SwiftData

@Model
final class Schedule {
    @Attribute(.unique) var id: UUID
    var timeOfDay: TimeOfDay
    var specificTime: Date?
    var daysOfWeek: [Int]
    var dosage: Double
    var withFood: Bool
    var notificationIds: [String]

    // User-customized label + icon. Empty = use TimeOfDay.defaultLabel / defaultIcon.
    var customLabel: String?
    var customIcon: String?

    init(
        id: UUID = UUID(),
        timeOfDay: TimeOfDay,
        specificTime: Date? = nil,
        daysOfWeek: [Int] = [],
        dosage: Double = 1,
        withFood: Bool = false,
        notificationIds: [String] = [],
        customLabel: String? = nil,
        customIcon: String? = nil
    ) {
        self.id = id
        self.timeOfDay = timeOfDay
        self.specificTime = specificTime
        self.daysOfWeek = daysOfWeek
        self.dosage = dosage
        self.withFood = withFood
        self.notificationIds = notificationIds
        self.customLabel = customLabel
        self.customIcon = customIcon
    }

    var displayLabel: String { customLabel ?? timeOfDay.defaultLabel }
    var displayIcon: String  { customIcon  ?? timeOfDay.defaultIcon  }
}
