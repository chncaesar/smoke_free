import Foundation
import Combine
import WidgetKit

final class DashboardViewModel: ObservableObject {
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var moneySaved: Double = 0
    @Published private(set) var nextMilestone: HealthMilestone? = nil
    @Published private(set) var nextMilestoneProgress: Double = 0
    @Published private(set) var nextMilestoneTimeRemaining: String = ""

    func update(from profile: UserProfile, logs: [SmokingLog], purchases: [PurchaseRecord] = []) {
        let prevStreakDays = streakDays
        streakDays = profile.actualStreakDays(logs: logs)
        moneySaved = profile.moneySaved(logs: logs, purchases: purchases)

        let milestones = AppConfig.healthMilestones

        let next = milestones.first { $0.requiredStreakDays > streakDays }
        nextMilestone = next

        if let next = next {
            let prevRequired = milestones.last { $0.requiredStreakDays <= streakDays }
            let start = prevRequired?.requiredStreakDays ?? 0
            let span = next.requiredStreakDays - start
            let progress = span > 0 ? Double(streakDays - start) / Double(span) : 0
            nextMilestoneProgress = min(max(progress, 0), 1)
            let remaining = next.requiredStreakDays - streakDays
            nextMilestoneTimeRemaining = "还需 \(remaining) 天连续控烟"
        } else {
            nextMilestoneProgress = 1.0
            nextMilestoneTimeRemaining = ""
        }

        writeWidgetData(profile: profile)

        if streakDays > prevStreakDays {
            let newlyUnlocked = milestones.filter {
                $0.requiredStreakDays > prevStreakDays && $0.requiredStreakDays <= streakDays
            }
            for milestone in newlyUnlocked {
                NotificationService.shared.sendMilestoneNotification(milestone: milestone)
            }
        }
    }

    // MARK: - 减量进度

    @Published private(set) var todayCount: Int = -1
    @Published private(set) var baselineCount: Int = 0
    @Published private(set) var reductionPercent: Double = 0
    @Published private(set) var todaySavings: Double = 0

    func updateReduction(todayLog: SmokingLog?, profile: UserProfile, purchases: [PurchaseRecord] = [], logs: [SmokingLog] = []) {
        baselineCount = Int(profile.cigarettesPerDayBefore)
        todayCount = todayLog.map { Int($0.count) } ?? -1
        guard baselineCount > 0, todayCount >= 0 else {
            reductionPercent = 0
            todaySavings = 0
            return
        }
        let reduced = max(0, baselineCount - todayCount)
        reductionPercent = Double(reduced) / Double(baselineCount)
        let pricePerCig = effectivePricePerCig(purchases: purchases, logs: logs, profile: profile)
        todaySavings = Double(reduced) * pricePerCig
    }

    // MARK: - 烟草开销对比

    @Published private(set) var annualBaselineCost: Double = 0
    @Published private(set) var yearsToGoal: Double = 0
    @Published private(set) var totalSpentOnSmokes: Double = 0

    func updateCost(profile: UserProfile, logs: [SmokingLog], purchases: [PurchaseRecord] = []) {
        let pricePerCig = effectivePricePerCig(purchases: purchases, logs: logs, profile: profile)
        guard pricePerCig > 0 else {
            annualBaselineCost = 0; yearsToGoal = 0; totalSpentOnSmokes = 0; return
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentLogs = logs.filter { ($0.date ?? .distantPast) >= Calendar.current.startOfDay(for: cutoff) }
        let currentDailyAvg: Double
        if recentLogs.isEmpty {
            currentDailyAvg = Double(Int(profile.cigarettesPerDayBefore))
        } else {
            let totalCount = recentLogs.reduce(0) { $0 + Int($1.count) }
            currentDailyAvg = Double(totalCount) / Double(recentLogs.count)
        }
        annualBaselineCost = currentDailyAvg * pricePerCig * 365
        guard annualBaselineCost > 0 else { yearsToGoal = 0; totalSpentOnSmokes = 0; return }
        yearsToGoal = profile.goalAmount / annualBaselineCost
        totalSpentOnSmokes = logs.reduce(0.0) { sum, log in
            let price = log.pricePerPackAtTime != 0 ? log.pricePerPackAtTime : profile.pricePerPack
            let perPack = max(1, log.cigarettesPerPackAtTime != 0 ? Int(log.cigarettesPerPackAtTime) : Int(profile.cigarettesPerPack))
            return sum + Double(Int(log.count)) * (price / Double(perPack))
        }
    }

    /// 当前有效的每支烟价格：最近购烟未消耗完则用购入价，否则回落个人资料价格
    func effectivePricePerCig(purchases: [PurchaseRecord], logs: [SmokingLog], profile: UserProfile) -> Double {
        guard let latest = purchases.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) else {
            return profile.pricePerPack / Double(max(1, Int(profile.cigarettesPerPack)))
        }
        let cal = Calendar.current
        let purchaseDay = cal.startOfDay(for: latest.date ?? Date())
        let totalBought = Int(latest.quantity) * 20
        let smokedSince = logs
            .filter { ($0.date ?? .distantPast) >= purchaseDay }
            .reduce(0) { $0 + Int($1.count) }
        if smokedSince < totalBought {
            return latest.pricePerPack / 20.0
        }
        return profile.pricePerPack / Double(max(1, Int(profile.cigarettesPerPack)))
    }

    func formattedYearsToGoal() -> String {
        guard yearsToGoal > 0 else { return "–" }
        if yearsToGoal >= 1 {
            return "约 \(Int(yearsToGoal)) 年"
        } else {
            return "约 \(Int(yearsToGoal * 12)) 个月"
        }
    }

    func formatCurrency(_ amount: Double, currencyCode: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "¥\(Int(amount))"
    }

    // MARK: - Widget 数据桥接

    private func writeWidgetData(profile: UserProfile) {
        guard let d = UserDefaults(suiteName: "group.com.smokefree.app") else { return }
        d.set(streakDays, forKey: "widget_streakDays")
        d.set(moneySaved, forKey: "widget_moneySaved")
        d.set(profile.currencyCode, forKey: "widget_currencyCode")
        if let next = nextMilestone {
            d.set(next.title, forKey: "widget_nextMilestoneName")
        } else {
            d.removeObject(forKey: "widget_nextMilestoneName")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func formattedMoneySaved(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: moneySaved)) ?? "¥\(String(format: "%.1f", moneySaved))"
    }
}
