import Foundation
import SwiftData

struct AchievementService {
    /// 评估并颁发成就，返回本次新解锁的徽章列表
    @discardableResult
    static func evaluateAndAward(
        profile: UserProfile,
        logs: [SmokingLog] = [],
        context: ModelContext
    ) -> [AchievementDefinition] {
        let streakDays = profile.actualStreakDays(logs: logs)
        let baseline = profile.cigarettesPerDayBefore

        // 获取已解锁的 badgeID 集合
        let fetchDescriptor = FetchDescriptor<UnlockedAchievement>()
        let existing = (try? context.fetch(fetchDescriptor)) ?? []
        let unlockedIDs = Set(existing.map(\.badgeID))

        // 预计算减量相关数据（有 logs 时才有意义）
        let sortedLogs = logs.sorted { $0.date > $1.date }
        let consecutiveDaysBelow = Self.consecutiveDaysBelow(baseline: baseline, logs: sortedLogs)
        let sevenDayAvg = Self.sevenDayAverage(logs: sortedLogs)

        var newlyUnlocked: [AchievementDefinition] = []

        for definition in AppConfig.achievementDefinitions {
            guard !unlockedIDs.contains(definition.id) else { continue }

            var qualifies = false

            if let required = definition.requiredStreakDays, streakDays >= required {
                qualifies = true
            }
            if let required = definition.requiredMoneySaved, profile.moneySaved(logs: logs) >= required {
                qualifies = true
            }
            if let required = definition.requiredConsecutiveDaysBelow, baseline > 0,
               consecutiveDaysBelow >= required {
                qualifies = true
            }
            if let required = definition.requiredReductionPercent, baseline > 0,
               sevenDayAvg <= Double(baseline) * required {
                qualifies = true
            }

            if qualifies {
                context.insert(UnlockedAchievement(badgeID: definition.id))
                newlyUnlocked.append(definition)
            }
        }

        return newlyUnlocked
    }

    // MARK: - 减量计算辅助

    /// 从最新一天起，连续低于基准的天数。无记录的天视为中断（未知）。
    private static func consecutiveDaysBelow(baseline: Int, logs: [SmokingLog]) -> Int {
        let cal = Calendar.current
        var count = 0
        var checkDate = cal.startOfDay(for: Date())

        for _ in 0..<365 {
            if let log = logs.first(where: { $0.date == checkDate }) {
                let effectiveBaseline = log.baselineAtTime ?? baseline
                if log.count < effectiveBaseline {
                    count += 1
                } else {
                    break
                }
            } else {
                break // 无记录视为中断
            }
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return count
    }

    /// 近 7 天日均吸烟量，无记录天计为 0，分母固定为 7。
    private static func sevenDayAverage(logs: [SmokingLog]) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let total = (0..<7).reduce(0) { sum, offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return sum }
            let count = logs.first(where: { $0.date == date })?.count ?? 0
            return sum + count
        }
        return Double(total) / 7.0
    }
}
