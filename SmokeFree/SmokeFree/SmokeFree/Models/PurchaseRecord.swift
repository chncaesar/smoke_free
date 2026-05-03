import Foundation
import SwiftData

@Model
final class PurchaseRecord {
    var id: UUID
    var date: Date
    var brand: String
    var quantity: Int
    var pricePerPack: Double
    var totalCost: Double
    var notes: String?

    init(
        date: Date,
        brand: String,
        quantity: Int,
        pricePerPack: Double,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.brand = brand
        self.quantity = quantity
        self.pricePerPack = pricePerPack
        self.totalCost = Double(quantity) * pricePerPack
        self.notes = notes
    }
}
