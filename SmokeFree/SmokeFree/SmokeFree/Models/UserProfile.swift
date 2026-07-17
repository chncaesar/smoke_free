import Foundation
import CoreData

private let defaultCigarettesPerPack = 20
private let defaultGoalAmount = 300_000.0
private let defaultGoalName = "宝马 3 系"

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
                      cigarettesPerPack: Int = defaultCigarettesPerPack,
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
        applyDefaultsIfNeeded()
    }

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        applyDefaultsIfNeeded()
    }

    private func applyDefaultsIfNeeded() {
        if id == nil { id = UUID() }
        if createdAt == nil { createdAt = Date() }
        if goalName == nil { goalName = defaultGoalName }
        if goalAmount == 0 { goalAmount = defaultGoalAmount }
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
        return streakDays(logs: logs, startingAt: cal.startOfDay(for: Date()))
    }

    func completedStreakDays(logs: [SmokingLog]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return 0 }
        return streakDays(logs: logs, startingAt: yesterday)
    }

    private func streakDays(logs: [SmokingLog], startingAt firstCheckDate: Date) -> Int {
        let cal = Calendar.current
        var checkDate = firstCheckDate
        let startOfQuitDate = cal.startOfDay(for: quitDate ?? Date())
        var count = 0

        while checkDate >= startOfQuitDate {
            if let log = logs.first(where: { log in
                guard let date = log.date else { return false }
                return cal.startOfDay(for: date) == checkDate
            }) {
                if !isSuccessfulControlDay(log) { break }
            }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return count
    }

    private func isSuccessfulControlDay(_ log: SmokingLog) -> Bool {
        let baseline = Int(log.baselineAtTime) != 0 ? Int(log.baselineAtTime) : Int(cigarettesPerDayBefore)
        let threshold = baseline > 0 ? baseline : 1
        return Int(log.count) < threshold
    }

    func completedDaysSinceQuit() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startOfQuitDate = cal.startOfDay(for: quitDate ?? Date())
        guard startOfQuitDate < today else { return 0 }
        return cal.dateComponents([.day], from: startOfQuitDate, to: today).day ?? 0
    }

    func moneySaved(logs: [SmokingLog], purchases: [PurchaseRecord] = []) -> Double {
        let exhaustionDate = Self.purchaseExhaustionDate(purchases: purchases, logs: logs)
        let latestPurchase = purchases.max(by: { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) })
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

    func completedMoneySaved(logs: [SmokingLog], purchases: [PurchaseRecord] = []) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let completedLogs = logs.filter { ($0.date ?? .distantFuture) < today }
        return moneySaved(logs: completedLogs, purchases: purchases)
    }

    static func perCigPrice(
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
           let pd = purchase.date,
           let exhaustion = exhaustionDate,
           let logDate = log.date,
           logDate >= Calendar.current.startOfDay(for: pd),
           logDate <= exhaustion {
            return purchase.pricePerPack / Double(defaultCigarettesPerPack)
        }
        return profilePricePerPack / Double(max(1, profilePerPack))
    }

    static func purchaseExhaustionDate(purchases: [PurchaseRecord], logs: [SmokingLog]) -> Date? {
        guard let latest = purchases.max(by: { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }) else { return nil }
        let cal = Calendar.current
        let purchaseDay = cal.startOfDay(for: latest.date ?? Date())
        let totalBought = Int(latest.quantity) * defaultCigarettesPerPack
        var cumulative = 0
        let sortedLogs = logs
            .compactMap { log -> (date: Date, count: Int32)? in
                guard let d = log.date else { return nil }
                return (d, log.count)
            }
            .filter { $0.date >= purchaseDay }
            .sorted { $0.date < $1.date }
        for entry in sortedLogs {
            let after = cumulative + Int(entry.count)
            if after >= totalBought {
                return entry.date
            }
            cumulative = after
        }
        return Date.distantFuture
    }

    func milestoneUnlockDate(streakDays: Int, requiredDays: Int) -> Date? {
        guard streakDays >= requiredDays else { return nil }
        let cal = Calendar.current
        let daysAgo = streakDays - requiredDays
        return cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))
    }
}
