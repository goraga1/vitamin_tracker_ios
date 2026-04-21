import Foundation
import SwiftData

@Model
final class IntakeLog {
    @Attribute(.unique) var id: UUID
    var supplement: Supplement?
    var scheduledFor: Date
    var takenAt: Date?
    var status: IntakeStatus
    var healthKitSynced: Bool = false
    var loggedVia: LogSource

    init(
        id: UUID = UUID(),
        supplement: Supplement?,
        scheduledFor: Date,
        takenAt: Date? = nil,
        status: IntakeStatus = .pending,
        loggedVia: LogSource = .app
    ) {
        self.id = id
        self.supplement = supplement
        self.scheduledFor = scheduledFor
        self.takenAt = takenAt
        self.status = status
        self.loggedVia = loggedVia
    }
}
