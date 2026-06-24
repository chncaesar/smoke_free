import Foundation
import CoreData

@objc(UserProfile)
public class UserProfile: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var quitDate: Date?
    @NSManaged public var cigarettesPerDayBefore: Int32
    @NSManaged public var pricePerPack: Double
    @NSManaged public var cigarettesPerPack: Int32
    @NSManaged public var currencyCode: String?
    @NSManaged public var name: String?
    @NSManaged public var goalAmount: Double
    @NSManaged public var goalName: String?
    @NSManaged public var createdAt: Date?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProfile> {
        NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }

    convenience init(context: NSManagedObjectContext,
                     quitDate: Date,
                     cigarettesPerDayBefore: Int,
                     pricePerPack: Double,
                     cigarettesPerPack: Int = 20,
                     currencyCode: String = "CNY",
                     name: String = "") {
        self.init(context: context)
        self.id = UUID()
        self.quitDate = quitDate
        self.cigarettesPerDayBefore = Int32(cigarettesPerDayBefore)
        self.pricePerPack = pricePerPack
        self.cigarettesPerPack = Int32(cigarettesPerPack)
        self.currencyCode = currencyCode
        self.name = name
        self.createdAt = Date()
        self.goalAmount = 300_000
        self.goalName = "宝马 3 系"
    }

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = Date() }
        if goalName == nil { goalName = "宝马 3 系" }
        if goalAmount == 0 { goalAmount = 300_000 }
    }
}

extension UserProfile {
    var smokeFreeSeconds: TimeInterval {
        Date().timeIntervalSince(quitDate ?? Date())
    }

    var streakDays: Int {
        max(0, Int(smokeFreeSeconds / 86400))
    }

    func actualStreakDays(logs: [SmokingLog]) -> Int {
        let cal = Calendar.current
        var count = 0
        var checkDate = cal.startOfDay(for: Date())
        let startOfQuitDate = cal.startOfDay(for: quitDate ?? Date())

        while checkDate >= startOfQuitDate {
            if let log = logs.first(where: { $0.date == checkDate }) {
                let baseline = Int(log.baselineAtTime) != 0 ? Int(log.baselineAtTime) : Int(cigarettesPerDayBefore)
                let threshold = baseline > 0 ? baseline : 1
                if Int(log.count) >= threshold { break }
            }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return count
    }

    func moneySaved(logs: [SmokingLog], purchases: [PurchaseRecord] = []) -> Double {
        let exhaustionDate = Self.purchaseExhaustionDate(purchases: purchases, logs: logs)
        let latestPurchase = purchases.max(by: { ($0.date ?? Date()) < ($1.date ?? Date()) })
        return logs.reduce(0.0) { sum, log in
            let baseline = log.baselineAtTime != 0 ? Int(log.baselineAtTime) : Int(cigarettesPerDayBefore)
            let reduced = baseline - Int(log.count)
            let perCigPrice = Self.perCigPrice(
                log: log,
                profilePricePerPack: pricePerPack,
                profilePerPack: Int(cigarettesPerPack),
                latestPurchase: latestPurchase,
                exhaustionDate: exhaustionDate
            )
            return sum + Double(reduced) * perCigPrice
        }
    }

    private static func perCigPrice(
        log: SmokingLog,
        profilePricePerPack: Double,
        profilePerPack: Int,
        latestPurchase: PurchaseRecord?,
        exhaustionDate: Date?
    ) -> Double {
        if log.pricePerPackAtTime != 0, log.cigarettesPerPackAtTime != 0 {
            return log.pricePerPackAtTime / Double(log.cigarettesPerPackAtTime)
        }
        if let purchase = latestPurchase,
           let exhaustion = exhaustionDate,
           let logDate = log.date,
           logDate <= exhaustion {
            return purchase.pricePerPack / 20.0
        }
        return profilePricePerPack / Double(max(1, profilePerPack))
    }

    private static func purchaseExhaustionDate(purchases: [PurchaseRecord], logs: [SmokingLog]) -> Date? {
        guard let latest = purchases.max(by: { ($0.date ?? Date()) < ($1.date ?? Date()) }) else { return nil }
        let cal = Calendar.current
        let purchaseDay = cal.startOfDay(for: latest.date ?? Date())
        let totalBought = Int(latest.quantity) * 20
        var cumulative = 0
        let sortedLogs = logs
            .filter { ($0.date ?? Date()) >= purchaseDay }
            .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        for log in sortedLogs {
            let after = cumulative + Int(log.count)
            if after >= totalBought {
                return log.date
            }
            cumulative = after
        }
        return nil
    }

    func milestoneUnlockDate(logs: [SmokingLog], requiredDays: Int) -> Date? {
        let cal = Calendar.current
        var checkDate = cal.startOfDay(for: Date())
        let logByDate = Dictionary(uniqueKeysWithValues: logs.compactMap { log in log.date.map { ($0, log) } })
        var consecutiveBelow = 0

        while checkDate >= cal.startOfDay(for: quitDate ?? Date()) {
            if let log = logByDate[checkDate] {
                let baseline = log.baselineAtTime != 0 ? Int(log.baselineAtTime) : Int(cigarettesPerDayBefore)
                let threshold = baseline > 0 ? baseline : 1
                if Int(log.count) >= threshold { break }
            }
            consecutiveBelow += 1
            if consecutiveBelow >= requiredDays { return checkDate }
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return nil
    }
}
