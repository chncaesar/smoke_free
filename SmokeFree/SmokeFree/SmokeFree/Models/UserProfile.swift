import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var quitDate: Date
    var cigarettesPerDayBefore: Int
    var pricePerPack: Double
    var cigarettesPerPack: Int
    var currencyCode: String
    var name: String
    var goalAmount: Double = 300_000
    var goalName: String = "宝马 3 系"
    var createdAt: Date

    init(
        quitDate: Date,
        cigarettesPerDayBefore: Int,
        pricePerPack: Double,
        cigarettesPerPack: Int = 20,
        currencyCode: String = "CNY",
        name: String = ""
    ) {
        self.id = UUID()
        self.quitDate = quitDate
        self.cigarettesPerDayBefore = cigarettesPerDayBefore
        self.pricePerPack = pricePerPack
        self.cigarettesPerPack = cigarettesPerPack
        self.currencyCode = currencyCode
        self.name = name
        self.createdAt = Date()
    }

    // MARK: - Computed helpers

    var smokeFreeSeconds: TimeInterval {
        Date().timeIntervalSince(quitDate)
    }

    /// 基于日历天数的控烟天数（不依赖吸烟记录）
    var streakDays: Int {
        max(0, Int(smokeFreeSeconds / 86400))
    }

    /// 连续控烟天数：从今天往前数，每天吸烟量 < 基准（或无记录）则计入，
    /// 遇到 count >= cigarettesPerDayBefore 的记录则停止。
    func actualStreakDays(logs: [SmokingLog]) -> Int {
        let cal = Calendar.current
        var count = 0
        var checkDate = cal.startOfDay(for: Date())
        let startOfQuitDate = cal.startOfDay(for: quitDate)

        while checkDate >= startOfQuitDate {
            if let log = logs.first(where: { $0.date == checkDate }) {
                let baseline = log.baselineAtTime ?? cigarettesPerDayBefore
                let threshold = baseline > 0 ? baseline : 1
                if log.count >= threshold { break }
            }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return count
    }

    /// 累计实际节省金额：每天实际少抽的支数 × 单支价格之和（使用日志快照的基准和价格）
    func moneySaved(logs: [SmokingLog]) -> Double {
        logs.reduce(0.0) { sum, log in
            let baseline = log.baselineAtTime ?? cigarettesPerDayBefore
            let price = log.pricePerPackAtTime ?? pricePerPack
            let perPack = max(1, log.cigarettesPerPackAtTime ?? cigarettesPerPack)
            let reduced = max(0, baseline - log.count)
            return sum + Double(reduced) * (price / Double(perPack))
        }
    }

    /// 计算里程碑解锁日期：从今天往前数，streak 第一次达到 requiredDays 的那一天
    func milestoneUnlockDate(logs: [SmokingLog], requiredDays: Int) -> Date? {
        let cal = Calendar.current
        var checkDate = cal.startOfDay(for: Date())
        let logByDate = Dictionary(uniqueKeysWithValues: logs.map { ($0.date, $0) })
        var consecutiveBelow = 0

        while checkDate >= cal.startOfDay(for: quitDate) {
            if let log = logByDate[checkDate] {
                let baseline = log.baselineAtTime ?? cigarettesPerDayBefore
                let threshold = baseline > 0 ? baseline : 1
                if log.count >= threshold { break }
            }
            consecutiveBelow += 1
            if consecutiveBelow >= requiredDays { return checkDate }
            guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return nil
    }
}
