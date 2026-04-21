import Foundation
import SwiftData

@Model
final class UserProfile {
    var displayName: String
    var age: Int?
    var biologicalSex: BiologicalSex
    var weightKg: Double?
    var streakDays: Int
    var lastStreakDate: Date?
    var onboardingCompleted: Bool
    var aiEnhancementEnabled: Bool
    var quietHoursStart: Date
    var quietHoursEnd: Date
    var memberSince: Date

    init(
        displayName: String = "Maya",
        biologicalSex: BiologicalSex = .unspecified,
        streakDays: Int = 0,
        onboardingCompleted: Bool = false,
        aiEnhancementEnabled: Bool = true
    ) {
        self.displayName = displayName
        self.biologicalSex = biologicalSex
        self.streakDays = streakDays
        self.onboardingCompleted = onboardingCompleted
        self.aiEnhancementEnabled = aiEnhancementEnabled
        self.memberSince = .now

        let cal = Calendar.current
        self.quietHoursStart = cal.date(from: DateComponents(hour: 22, minute: 0)) ?? .now
        self.quietHoursEnd   = cal.date(from: DateComponents(hour: 6,  minute: 0)) ?? .now
    }
}
