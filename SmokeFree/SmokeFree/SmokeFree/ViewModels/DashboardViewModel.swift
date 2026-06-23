import Foundation
import WidgetKit

@Observable
final class DashboardViewModel {
    private(set) var streakDays: Int = 0
    private(set) var moneySaved: Double = 0
    private(set) var nextMilestone: HealthMilestone? = nil
    private(set) var nextMilestoneProgress: Double = 0
    private(set) var nextMilestoneTimeRemaining: String = ""

    func update(from profile: UserProfile, logs: [SmokingLog]) {
        let prevStreakDays = streakDays
        streakDays = profile.actualStreakDays(logs: logs)
        moneySaved = profile.moneySaved(logs: logs)

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

    private(set) var todayCount: Int = -1
    private(set) var baselineCount: Int = 0
    private(set) var reductionPercent: Double = 0
    private(set) var todaySavings: Double = 0

    func updateReduction(todayLog: SmokingLog?, profile: UserProfile) {
        baselineCount = profile.cigarettesPerDayBefore
        todayCount = todayLog?.count ?? -1
        guard baselineCount > 0, todayCount >= 0, profile.cigarettesPerPack > 0 else {
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

    func formattedMoneySaved(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: moneySaved)) ?? "¥\(String(format: "%.1f", moneySaved))"
    }
}
