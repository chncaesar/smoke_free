import Foundation
import CoreData

// Regression coverage: AchievementServiceTests.
struct AchievementService {
    /// 评估并颁发成就，返回本次新解锁的徽章列表
    @discardableResult
    static func evaluateAndAward(
        profile: UserProfile,
        logs: [SmokingLog] = [],
        purchases: [PurchaseRecord] = [],
        context: NSManagedObjectContext
    ) -> [AchievementDefinition] {
        let completedStreakDays = profile.completedStreakDays(logs: logs)
        let baseline = profile.cigarettesPerDayBefore

        // 获取已解锁的 badgeID 集合
        let fetchRequest = NSFetchRequest<UnlockedAchievement>(entityName: "UnlockedAchievement")
        let existing = (try? context.fetch(fetchRequest)) ?? []
        let unlockedIDs = Set(existing.map(\.badgeID))

        // 预计算减量相关数据（有 logs 时才有意义）
        let sortedLogs = logs.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        let sevenDayAvg = Self.sevenDayAverage(profile: profile, logs: sortedLogs)

        var newlyUnlocked: [AchievementDefinition] = []

        for definition in AppConfig.achievementDefinitions {
            guard !unlockedIDs.contains(definition.id) else { continue }

            var qualifies = false

            if let required = definition.requiredStreakDays, completedStreakDays >= required {
                qualifies = true
            }
            if let required = definition.requiredMoneySaved,
               profile.completedMoneySaved(logs: logs, purchases: purchases) >= required {
                qualifies = true
            }
            if let required = definition.requiredConsecutiveDaysBelow, baseline > 0,
               completedStreakDays >= required {
                qualifies = true
            }
            if let required = definition.requiredReductionPercent, baseline > 0,
               sevenDayAvg <= Double(baseline) * required {
                qualifies = true
            }

            if qualifies {
                _ = UnlockedAchievement(context: context, badgeID: definition.id)
                newlyUnlocked.append(definition)
            }
        }

        try? context.save()
        return newlyUnlocked
    }

    // MARK: - 减量计算辅助

    /// 近 7 个已结束自然日的日均吸烟量，无记录天计为 0，分母固定为 7。
    private static func sevenDayAverage(profile: UserProfile, logs: [SmokingLog]) -> Double {
        guard profile.completedDaysSinceQuit() >= 7 else { return .infinity }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let total = (1...7).reduce(0) { sum, offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return sum }
            let count = Int(logs.first(where: { log in
                guard let logDate = log.date else { return false }
                return cal.startOfDay(for: logDate) == date
            })?.count ?? 0)
            return sum + count
        }
        return Double(total) / 7.0
    }
}
