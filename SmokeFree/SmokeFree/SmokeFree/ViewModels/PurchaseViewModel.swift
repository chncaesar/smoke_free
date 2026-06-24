import Foundation
import Combine
import CoreData

final class PurchaseViewModel: ObservableObject {
    @Published var showAddSheet = false

    // 新购烟表单
    @Published var newBrand = ""
    @Published var newQuantity = 1
    @Published var newPricePerPack: Double = 25.0
    @Published var newDate = Date()
    @Published var newNotes = ""

    var isFormValid: Bool {
        !newBrand.trimmingCharacters(in: .whitespaces).isEmpty && newQuantity > 0 && newPricePerPack > 0
    }

    func totalSpent(purchases: [PurchaseRecord]) -> Double {
        purchases.reduce(0) { $0 + $1.totalCost }
    }

    func spentThisMonth(purchases: [PurchaseRecord]) -> Double {
        let cal = Calendar.current
        let now = Date()
        return purchases
            .filter { cal.isDate($0.date ?? .distantPast, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalCost }
    }

    /// 按月份分组，每组 (monthLabel, records)
    func groupedByMonth(purchases: [PurchaseRecord]) -> [(String, [PurchaseRecord])] {
        let sorted = purchases.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 M 月"
        var groups: [(String, [PurchaseRecord])] = []
        var current: (String, [PurchaseRecord])? = nil
        for p in sorted {
            let label = formatter.string(from: p.date ?? Date())
            if current?.0 == label {
                current!.1.append(p)
            } else {
                if let c = current { groups.append(c) }
                current = (label, [p])
            }
        }
        if let c = current { groups.append(c) }
        return groups
    }

    func addPurchase(context: NSManagedObjectContext) {
        let record = PurchaseRecord(
            context: context,
            date: newDate,
            brand: newBrand.trimmingCharacters(in: .whitespaces),
            quantity: newQuantity,
            pricePerPack: newPricePerPack,
            notes: newNotes.isEmpty ? nil : newNotes
        )
        context.insert(record)
        resetForm()
        showAddSheet = false
    }

    private func resetForm() {
        newBrand = ""
        newQuantity = 1
        newPricePerPack = 25.0
        newDate = Date()
        newNotes = ""
    }
}
