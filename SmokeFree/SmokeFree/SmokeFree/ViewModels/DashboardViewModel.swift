import Foundation
import Combine
import CoreData
import WidgetKit

final class DashboardViewModel: ObservableObject {
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var moneySaved: Double = 0
    @Published private(set) var nextMilestone: HealthMilestone? = nil
    @Published private(set) var nextMilestoneProgress: Double = 0
    @Published private(set) var nextMilestoneTimeRemaining: String = ""
    private var completedStreakDays: Int = 0

    private static let notifiedMilestonesKey = "notified_milestones"

    private static func isMilestoneNotified(_ milestoneID: String) -> Bool {
        let set = Set(UserDefaults.standard.stringArray(forKey: notifiedMilestonesKey) ?? [])
        return set.contains(milestoneID)
    }

    private static func markMilestoneNotified(_ milestoneID: String) {
        var set = Set(UserDefaults.standard.stringArray(forKey: notifiedMilestonesKey) ?? [])
        set.insert(milestoneID)
        UserDefaults.standard.set(Array(set), forKey: notifiedMilestonesKey)
    }

    func update(from profile: UserProfile, logs: [SmokingLog], purchases: [PurchaseRecord] = []) {
        let prevCompletedStreakDays = completedStreakDays
        streakDays = profile.actualStreakDays(logs: logs)
        completedStreakDays = profile.completedStreakDays(logs: logs)
        moneySaved = profile.moneySaved(logs: logs, purchases: purchases)

        let milestones = AppConfig.healthMilestones

        let next = milestones.first { $0.requiredStreakDays > completedStreakDays }
        nextMilestone = next

        if let next = next {
            let prevRequired = milestones.last { $0.requiredStreakDays <= completedStreakDays }
            let start = prevRequired?.requiredStreakDays ?? 0
            let span = next.requiredStreakDays - start
            let progress = span > 0 ? Double(completedStreakDays - start) / Double(span) : 0
            nextMilestoneProgress = min(max(progress, 0), 1)
            let remaining = next.requiredStreakDays - completedStreakDays
            nextMilestoneTimeRemaining = "还需 \(remaining) 天连续控烟"
        } else {
            nextMilestoneProgress = 1.0
            nextMilestoneTimeRemaining = ""
        }

        writeWidgetData(profile: profile)

        if completedStreakDays > prevCompletedStreakDays {
            let newlyUnlocked = milestones.filter {
                $0.requiredStreakDays > prevCompletedStreakDays && $0.requiredStreakDays <= completedStreakDays
            }
            for milestone in newlyUnlocked {
                if !Self.isMilestoneNotified(milestone.id) {
                    NotificationService.shared.sendMilestoneNotification(milestone: milestone)
                    Self.markMilestoneNotified(milestone.id)
                }
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
        let pricePerCig = effectivePricePerCig(purchases: purchases, logs: logs, profile: profile, todayLog: todayLog)
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
        let latestPurchase = purchases.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) })
        let exhaustionDate = UserProfile.purchaseExhaustionDate(purchases: purchases, logs: logs)
        let profilePP = profile.pricePerPack
        let profileCP = max(1, Int(profile.cigarettesPerPack))
        totalSpentOnSmokes = logs.reduce(0.0) { sum, log in
            let perCig = UserProfile.perCigPrice(
                log: log,
                profilePricePerPack: profilePP,
                profilePerPack: profileCP,
                latestPurchase: latestPurchase,
                exhaustionDate: exhaustionDate
            )
            return sum + Double(Int(log.count)) * perCig
        }
    }

    func processAfterUpdate(profile: UserProfile, logs: [SmokingLog], purchases: [PurchaseRecord], context: NSManagedObjectContext) {
        AchievementService.evaluateAndAward(profile: profile, logs: logs, purchases: purchases, context: context)
        if todayCount == 0 {
            Task { await HealthKitService.shared.recordSmokeFreeToday() }
        }
    }

    func ensureTodayReminderIfNeeded(hasLoggedToday: Bool) {
        NotificationService.shared.ensureTodayReminderIfNeeded(hasLoggedToday: hasLoggedToday)
    }

    func exportData(context: NSManagedObjectContext) throws -> URL {
        try DataExportService.exportData(context: context)
    }

    func saveBaselineChanges(
        profile: UserProfile,
        logs: [SmokingLog],
        context: NSManagedObjectContext,
        newBaseline: Int,
        newPrice: Double,
        newPerPack: Int
    ) {
        for log in logs where log.baselineAtTime == 0 || log.pricePerPackAtTime == 0 || log.cigarettesPerPackAtTime == 0 {
            if log.baselineAtTime == 0 { log.baselineAtTime = Int32(profile.cigarettesPerDayBefore) }
            if log.pricePerPackAtTime == 0 { log.pricePerPackAtTime = profile.pricePerPack }
            if log.cigarettesPerPackAtTime == 0 { log.cigarettesPerPackAtTime = Int32(profile.cigarettesPerPack) }
        }
        profile.cigarettesPerDayBefore = Int32(newBaseline)
        profile.pricePerPack = newPrice
        profile.cigarettesPerPack = Int32(newPerPack)
        try? context.save()
    }

    /// 当前有效的每支烟价格（与 moneySaved 中的 perCigPrice 三级优先级一致）
    func effectivePricePerCig(purchases: [PurchaseRecord], logs: [SmokingLog], profile: UserProfile, todayLog: SmokingLog? = nil) -> Double {
        if let log = todayLog, log.pricePerPackAtTime != 0, log.cigarettesPerPackAtTime != 0 {
            return log.pricePerPackAtTime / Double(log.cigarettesPerPackAtTime)
        }
        guard let latest = purchases.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) else {
            return profile.pricePerPack / Double(max(1, Int(profile.cigarettesPerPack)))
        }
        let exhaustionDate = UserProfile.purchaseExhaustionDate(purchases: purchases, logs: logs) ?? Date.distantFuture
        let today = Calendar.current.startOfDay(for: Date())
        if today <= exhaustionDate {
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
