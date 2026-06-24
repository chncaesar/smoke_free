import Foundation
import CoreData

@objc(SmokingLog)
public class SmokingLog: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var count: Int32
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var baselineAtTime: Int32
    @NSManaged public var pricePerPackAtTime: Double
    @NSManaged public var cigarettesPerPackAtTime: Int32

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SmokingLog> {
        NSFetchRequest<SmokingLog>(entityName: "SmokingLog")
    }

    convenience init(context: NSManagedObjectContext, date: Date, count: Int, notes: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.count = Int32(count)
        self.notes = notes
        self.createdAt = Date()
    }

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = Date() }
        if date == nil { date = Calendar.current.startOfDay(for: Date()) }
    }
}
