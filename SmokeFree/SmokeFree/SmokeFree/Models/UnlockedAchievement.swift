import Foundation
import CoreData

@objc(UnlockedAchievement)
public class UnlockedAchievement: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var badgeID: String?
    @NSManaged public var unlockedAt: Date?
    @NSManaged public var isNewlySeen: Bool

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UnlockedAchievement> {
        NSFetchRequest<UnlockedAchievement>(entityName: "UnlockedAchievement")
    }

    convenience init(context: NSManagedObjectContext, badgeID: String) {
        self.init(context: context)
        self.id = UUID()
        self.badgeID = badgeID
        self.unlockedAt = Date()
        self.isNewlySeen = true
    }

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        if id == nil { id = UUID() }
        if unlockedAt == nil { unlockedAt = Date() }
    }

    static func changeToken<S: Sequence>(for achievements: S) -> String where S.Element == UnlockedAchievement {
        achievements.map { achievement in
            [
                achievement.objectID.uriRepresentation().absoluteString,
                achievement.badgeID ?? "",
                String(achievement.unlockedAt?.timeIntervalSince1970 ?? 0),
                String(achievement.isNewlySeen)
            ].joined(separator: ":")
        }
        .sorted()
        .joined(separator: "|")
    }
}
