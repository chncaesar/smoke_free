import SwiftUI
import CoreData

@main
struct SmokeFreeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init() {
        container = NSPersistentCloudKitContainer(name: "SmokeFree", managedObjectModel: Self.model)

        #if targetEnvironment(simulator)
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.cloudKitContainerOptions = nil
        #else
        let storeDescription = container.persistentStoreDescriptions.first!
        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.smokefree.app")
        #endif

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data store failed: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static var model: NSManagedObjectModel {
        let m = NSManagedObjectModel()

        let profile = NSEntityDescription()
        profile.name = "UserProfile"
        profile.managedObjectClassName = NSStringFromClass(UserProfile.self)
        profile.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false),
            ("quitDate", .dateAttributeType, false),
            ("cigarettesPerDayBefore", .integer32AttributeType, false),
            ("pricePerPack", .doubleAttributeType, false),
            ("cigarettesPerPack", .integer32AttributeType, false),
            ("currencyCode", .stringAttributeType, true),
            ("name", .stringAttributeType, true),
            ("goalAmount", .doubleAttributeType, false),
            ("goalName", .stringAttributeType, true),
            ("createdAt", .dateAttributeType, false),
        ])

        let log = NSEntityDescription()
        log.name = "SmokingLog"
        log.managedObjectClassName = NSStringFromClass(SmokingLog.self)
        log.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false),
            ("date", .dateAttributeType, false),
            ("count", .integer32AttributeType, false),
            ("notes", .stringAttributeType, true),
            ("createdAt", .dateAttributeType, false),
            ("baselineAtTime", .integer32AttributeType, false),
            ("pricePerPackAtTime", .doubleAttributeType, false),
            ("cigarettesPerPackAtTime", .integer32AttributeType, false),
        ])

        let purchase = NSEntityDescription()
        purchase.name = "PurchaseRecord"
        purchase.managedObjectClassName = NSStringFromClass(PurchaseRecord.self)
        purchase.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false),
            ("date", .dateAttributeType, false),
            ("brand", .stringAttributeType, true),
            ("quantity", .integer32AttributeType, false),
            ("pricePerPack", .doubleAttributeType, false),
            ("totalCost", .doubleAttributeType, false),
            ("notes", .stringAttributeType, true),
        ])

        let goal = NSEntityDescription()
        goal.name = "Goal"
        goal.managedObjectClassName = NSStringFromClass(Goal.self)
        goal.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false),
            ("title", .stringAttributeType, true),
            ("reward", .stringAttributeType, true),
            ("targetDays", .integer32AttributeType, false),
            ("targetMoneySaved", .doubleAttributeType, false),
            ("isCompleted", .booleanAttributeType, false),
            ("completedAt", .dateAttributeType, true),
            ("sortOrder", .integer32AttributeType, false),
            ("createdAt", .dateAttributeType, false),
        ])

        let achievement = NSEntityDescription()
        achievement.name = "UnlockedAchievement"
        achievement.managedObjectClassName = NSStringFromClass(UnlockedAchievement.self)
        achievement.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false),
            ("badgeID", .stringAttributeType, false),
            ("unlockedAt", .dateAttributeType, false),
            ("isNewlySeen", .booleanAttributeType, false),
        ])

        m.entities = [profile, log, purchase, goal, achievement]
        return m
    }
}

extension NSAttributeDescription {
    static func attrs(_ defs: [(String, NSAttributeType, Bool)]) -> [NSPropertyDescription] {
        defs.map { name, type, optional in
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            return a
        }
    }
}
