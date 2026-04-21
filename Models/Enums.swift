import Foundation

enum SupplementForm: String, Codable, CaseIterable {
    case tablet, capsule, softgel, liquid, powder, gummy
}

enum IntakeStatus: String, Codable {
    case pending, taken, skipped, missed
}

enum LogSource: String, Codable {
    case app, widget, notification, siri
}

enum TimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning, midday, evening, night, custom
    var id: String { rawValue }

    var defaultIcon: String {
        switch self {
        case .morning: "☀"
        case .midday:  "🌤"
        case .evening: "🌙"
        case .night:   "⭐"
        case .custom:  "☕"
        }
    }

    var defaultLabel: String {
        switch self {
        case .morning: "Morning"
        case .midday:  "Midday"
        case .evening: "Evening"
        case .night:   "Night"
        case .custom:  "Custom"
        }
    }
}

enum BiologicalSex: String, Codable {
    case male, female, other, unspecified
}
