import Foundation
import SwiftData
import WidgetKit

@Observable
final class DashboardViewModel {
    private(set) var streakDays: Int = 0
    private(set) var moneySaved: Double = 0
    private(set) var nextMilestone: HealthMilestone? = nil
    private(set) var nextMilestoneProgress: Double = 0
    private(set) var nextMilestoneTimeRemaining: String = ""

    func update(from profile: UserProfile, logs: [SmokingLog]) {
        streakDays = profile.actualStreakDays(logs: logs)
        moneySaved = profile.moneySaved(logs: logs)

        let elapsed = profile.smokeFreeSeconds
        let milestones = AppConfig.healthMilestones

        // 找到下一个未解锁的里程碑
        let next = milestones.first { $0.offsetSeconds > elapsed }
        nextMilestone = next

        if let next = next {
            // 找当前区间的起点（上一个里程碑的时间，或 0）
            let prev = milestones.last { $0.offsetSeconds <= elapsed }
            let start = prev?.offsetSeconds ?? 0
            let span = next.offsetSeconds - start
            let progress = (elapsed - start) / span
            nextMilestoneProgress = min(max(progress, 0), 1)
            nextMilestoneTimeRemaining = formatTimeRemaining(next.offsetSeconds - elapsed)
        } else {
            nextMilestoneProgress = 1.0
            nextMilestoneTimeRemaining = ""
        }

        writeWidgetData(profile: profile)
    }

    // MARK: - Widget 数据桥接

    // MARK: - 减量进度

    private(set) var todayCount: Int = -1        // -1 表示今天尚未记录
    private(set) var baselineCount: Int = 0
    private(set) var reductionPercent: Double = 0 // 0~1
    private(set) var todaySavings: Double = 0     // 今日少抽换算的金额

    func updateReduction(todayLog: SmokingLog?, profile: UserProfile) {
        baselineCount = profile.cigarettesPerDayBefore
        todayCount = todayLog?.count ?? -1
        guard baselineCount > 0, todayCount >= 0 else {
            reductionPercent = 0
            todaySavings = 0
            return
        }
        let reduced = max(0, baselineCount - todayCount)
        reductionPercent = Double(reduced) / Double(baselineCount)
        let pricePerCig = profile.pricePerPack / Double(profile.cigarettesPerPack)
        todaySavings = Double(reduced) * pricePerCig
    }

    // MARK: - 烟草开销对比

    private(set) var annualBaselineCost: Double = 0
    private(set) var yearsToGoal: Double = 0
    private(set) var totalSpentOnSmokes: Double = 0

    func updateCost(profile: UserProfile, logs: [SmokingLog]) {
        guard profile.cigarettesPerPack > 0 else {
            annualBaselineCost = 0; yearsToGoal = 0; totalSpentOnSmokes = 0; return
        }
        let pricePerCig = profile.pricePerPack / Double(profile.cigarettesPerPack)
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentLogs = logs.filter { $0.date >= Calendar.current.startOfDay(for: cutoff) }
        let currentDailyAvg: Double
        if recentLogs.isEmpty {
            currentDailyAvg = Double(profile.cigarettesPerDayBefore)
        } else {
            currentDailyAvg = Double(recentLogs.reduce(0) { $0 + $1.count }) / Double(recentLogs.count)
        }
        annualBaselineCost = currentDailyAvg * pricePerCig * 365
        guard annualBaselineCost > 0 else { yearsToGoal = 0; totalSpentOnSmokes = 0; return }
        yearsToGoal = profile.goalAmount / annualBaselineCost
        totalSpentOnSmokes = logs.reduce(0.0) { sum, log in
            let price   = log.pricePerPackAtTime    ?? profile.pricePerPack
            let perPack = max(1, log.cigarettesPerPackAtTime ?? profile.cigarettesPerPack)
            return sum + Double(log.count) * (price / Double(perPack))
        }
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

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 3600 {
            return "\(s / 60) 分钟后"
        } else if s < 86400 {
            return "\(s / 3600) 小时后"
        } else {
            return "\(s / 86400) 天后"
        }
    }

    /// 格式化节省金额
    func formattedMoneySaved(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: moneySaved)) ?? "¥\(String(format: "%.1f", moneySaved))"
    }
}
