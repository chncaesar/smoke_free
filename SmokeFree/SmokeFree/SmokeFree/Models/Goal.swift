import Foundation
import CoreData

@objc(Goal)
public class Goal: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var reward: String?
    @NSManaged public var targetDays: Int32
    @NSManaged public var targetMoneySaved: Double
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedAt: Date?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Goal> {
        NSFetchRequest<Goal>(entityName: "Goal")
    }

    convenience init(context: NSManagedObjectContext, title: String, reward: String,
                     targetDays: Int, targetMoneySaved: Double? = nil, sortOrder: Int = 0) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.reward = reward
        self.targetDays = Int32(targetDays)
        self.targetMoneySaved = targetMoneySaved ?? 0
        self.isCompleted = false
        self.completedAt = nil
        self.sortOrder = Int32(sortOrder)
        self.createdAt = Date()
    }

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = Date() }
    }
}
