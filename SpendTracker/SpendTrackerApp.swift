import SwiftUI
import SwiftData

@main
struct SpendTrackerApp: App {

    private let appGroupID = "group.com.yourname.spendtracker" // ← update this

    var sharedModelContainer: ModelContainer = {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.harshal.spendtracker"),
        // ↑ update this too
        let config = ModelConfiguration(
            url: containerURL.appendingPathComponent("transactions.store")
        ) as ModelConfiguration? else {
            fatalError("Could not set up App Group container")
        }

        do {
            return try ModelContainer(for: Transaction.self, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
