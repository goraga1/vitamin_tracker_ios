import SwiftUI
import SwiftData

@main
struct VitaminTrackerApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Supplement.self,
            Ingredient.self,
            Schedule.self,
            IntakeLog.self,
            UserProfile.self,
            SupplementCatalog.self,
        ])

        // Store lives in the App Group container so the widget extension
        // (added in Phase 1c) reads and writes the same database. If the
        // group isn't provisioned yet, SwiftData falls back to the app's
        // default location.
        let appGroup = "group.app.vitamintracker"
        let config: ModelConfiguration = {
            if let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
                .appendingPathComponent("VitaminTracker.sqlite") {
                return ModelConfiguration(schema: schema, url: url)
            }
            return ModelConfiguration(schema: schema)
        }()

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("ModelContainer failed to initialize: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootGate()
        }
        .modelContainer(container)
    }
}
