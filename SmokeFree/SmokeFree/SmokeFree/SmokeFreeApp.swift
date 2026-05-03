import SwiftUI
import SwiftData

@main
struct SmokeFreeApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            SmokingLog.self,
            PurchaseRecord.self,
            Goal.self,
            UnlockedAchievement.self,
        ])
        #if targetEnvironment(simulator)
        let cloudKit = ModelConfiguration.CloudKitDatabase.none
        #else
        let cloudKit = ModelConfiguration.CloudKitDatabase.automatic
        #endif
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKit
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
