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

        let description = container.persistentStoreDescriptions.first!
        #if DEBUG || targetEnvironment(simulator)
        description.cloudKitContainerOptions = nil
        #else
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.smokefree.app"
        )
        #endif

        loadPersistentStores(description: description, allowsLocalFallback: true)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private func loadPersistentStores(description: NSPersistentStoreDescription, allowsLocalFallback: Bool) {
        container.loadPersistentStores { [weak self] _, error in
            guard let self, let error = error as NSError? else { return }

            #if !DEBUG && !targetEnvironment(simulator)
            if allowsLocalFallback, description.cloudKitContainerOptions != nil {
                print("=== CloudKit store load failed; retrying local-only Core Data ===")
                self.logStoreLoadError(error)
                description.cloudKitContainerOptions = nil
                self.loadPersistentStores(description: description, allowsLocalFallback: false)
                return
            }
            #endif

            print("=== Core Data load failed ===")
            self.logStoreLoadError(error)
            fatalError("Core Data store failed: \(error.localizedDescription)")
        }
    }

    private func logStoreLoadError(_ error: NSError) {
        print("Domain: \(error.domain)")
        print("Code: \(error.code)")
        print("UserInfo: \(error.userInfo)")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("Underlying: domain=\(underlying.domain), code=\(underlying.code), userInfo=\(underlying.userInfo)")
        }
    }

    static let model: NSManagedObjectModel = makeModel()

    private static func makeModel() -> NSManagedObjectModel {
        let m = NSManagedObjectModel()

        let profile = NSEntityDescription()
        profile.name = "UserProfile"
        profile.managedObjectClassName = NSStringFromClass(UserProfile.self)
        profile.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false, UUID()),
            ("quitDate", .dateAttributeType, false, Date.distantPast),
            ("cigarettesPerDayBefore", .integer32AttributeType, false, 0),
            ("pricePerPack", .doubleAttributeType, false, 0.0),
            ("cigarettesPerPack", .integer32AttributeType, false, 0),
            ("currencyCode", .stringAttributeType, true, nil),
            ("name", .stringAttributeType, true, nil),
            ("goalAmount", .doubleAttributeType, false, 0.0),
            ("goalName", .stringAttributeType, true, nil),
            ("createdAt", .dateAttributeType, false, Date.distantPast),
        ])

        let log = NSEntityDescription()
        log.name = "SmokingLog"
        log.managedObjectClassName = NSStringFromClass(SmokingLog.self)
        log.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false, UUID()),
            ("date", .dateAttributeType, false, Date.distantPast),
            ("count", .integer32AttributeType, false, 0),
            ("notes", .stringAttributeType, true, nil),
            ("createdAt", .dateAttributeType, false, Date.distantPast),
            ("baselineAtTime", .integer32AttributeType, false, 0),
            ("pricePerPackAtTime", .doubleAttributeType, false, 0.0),
            ("cigarettesPerPackAtTime", .integer32AttributeType, false, 0),
        ])

        let purchase = NSEntityDescription()
        purchase.name = "PurchaseRecord"
        purchase.managedObjectClassName = NSStringFromClass(PurchaseRecord.self)
        purchase.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false, UUID()),
            ("date", .dateAttributeType, false, Date.distantPast),
            ("brand", .stringAttributeType, true, nil),
            ("quantity", .integer32AttributeType, false, 0),
            ("pricePerPack", .doubleAttributeType, false, 0.0),
            ("totalCost", .doubleAttributeType, false, 0.0),
            ("notes", .stringAttributeType, true, nil),
        ])

        let goal = NSEntityDescription()
        goal.name = "Goal"
        goal.managedObjectClassName = NSStringFromClass(Goal.self)
        goal.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false, UUID()),
            ("title", .stringAttributeType, true, nil),
            ("reward", .stringAttributeType, true, nil),
            ("targetDays", .integer32AttributeType, false, 0),
            ("targetMoneySaved", .doubleAttributeType, false, 0.0),
            ("isCompleted", .booleanAttributeType, false, false),
            ("completedAt", .dateAttributeType, true, nil),
            ("sortOrder", .integer32AttributeType, false, 0),
            ("createdAt", .dateAttributeType, false, Date.distantPast),
        ])

        let achievement = NSEntityDescription()
        achievement.name = "UnlockedAchievement"
        achievement.managedObjectClassName = NSStringFromClass(UnlockedAchievement.self)
        achievement.properties = NSAttributeDescription.attrs([
            ("id", .UUIDAttributeType, false, UUID()),
            ("badgeID", .stringAttributeType, false, ""),
            ("unlockedAt", .dateAttributeType, false, Date.distantPast),
            ("isNewlySeen", .booleanAttributeType, false, false),
        ])

        m.entities = [profile, log, purchase, goal, achievement]
        return m
    }
}

extension NSAttributeDescription {
    static func attrs(_ defs: [(String, NSAttributeType, Bool, Any?)]) -> [NSPropertyDescription] {
        defs.map { name, type, optional, defaultValue in
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            if let dv = defaultValue {
                a.defaultValue = dv
            }
            return a
        }
    }
}
