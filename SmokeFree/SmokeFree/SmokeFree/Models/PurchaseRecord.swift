import Foundation
import CoreData

@objc(PurchaseRecord)
public class PurchaseRecord: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var brand: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var pricePerPack: Double
    @NSManaged public var totalCost: Double
    @NSManaged public var notes: String?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PurchaseRecord> {
        NSFetchRequest<PurchaseRecord>(entityName: "PurchaseRecord")
    }

    convenience init(context: NSManagedObjectContext, date: Date, brand: String,
                     quantity: Int, pricePerPack: Double, notes: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.date = date
        self.brand = brand
        self.quantity = Int32(quantity)
        self.pricePerPack = pricePerPack
        self.totalCost = Double(quantity) * pricePerPack
        self.notes = notes
    }

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        if id == nil { id = UUID() }
    }
}
