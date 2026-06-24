import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct AchievementServiceTests {

    // MARK: - 辅助：内存 Core Data 容器

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    /// 创建连续 N 天（从今天往回）的日志，每天 count 低于 baseline
    private func makeConsecutiveLogs(days: Int, count: Int = 10, context: NSManagedObjectContext) -> [SmokingLog] {
        let cal = Calendar.current
        var logs: [SmokingLog] = []
        for offset in 0..<days {
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            let log = SmokingLog(context: context, date: date, count: count)
            log.baselineAtTime = 20
            log.pricePerPackAtTime = 25
            log.cigarettesPerPackAtTime = 20
            logs.append(log)
        }
        return logs
    }

    // MARK: - 按天数颁发（consecutiveDaysBelow）

    @Test func awards_streak1Day_whenStreakIs1() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date().addingTimeInterval(-86400), // 1 天前
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let logs = makeConsecutiveLogs(days: 1, context: context)

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        let ids = newBadges.map(\.id)
        #expect(ids.contains("streak_1_day"))
    }

    @Test func awards_multipleStreakBadges_when7DayStreak() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date().addingTimeInterval(-86400 * 7), // 7 天前
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let logs = makeConsecutiveLogs(days: 7, context: context)

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        let ids = newBadges.map(\.id)
        #expect(ids.contains("streak_1_day"))
        #expect(ids.contains("streak_3_days"))
        #expect(ids.contains("streak_1_week"))
        #expect(!ids.contains("streak_1_month")) // 30 天未到
    }

    @Test func noAwards_whenStreakIsZero() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date(), // 刚开始
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)

        #expect(newBadges.isEmpty)
    }

    // MARK: - 防重复颁发

    @Test func doesNotRewAward_alreadyUnlockedBadge() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date().addingTimeInterval(-86400),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let logs = makeConsecutiveLogs(days: 1, context: context)

        // 第一次颁发
        let first = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)
        #expect(first.map(\.id).contains("streak_1_day"))

        // 第二次不应重复颁发
        let second = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)
        #expect(!second.map(\.id).contains("streak_1_day"))
    }

    // MARK: - 全部解锁

    @Test func awards_allStreakBadges_when365DayStreak() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date().addingTimeInterval(-86400 * 365),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let logs = makeConsecutiveLogs(days: 365, context: context)

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        let ids = newBadges.map(\.id)
        let expectedIDs = ["streak_1_day", "streak_3_days", "streak_1_week",
                           "streak_1_month", "streak_3_months", "streak_6_months", "streak_1_year"]
        for expected in expectedIDs {
            #expect(ids.contains(expected), "应包含 \(expected)")
        }
    }

    // MARK: - 已解锁成就写入数据库

    @Test func persists_unlockedAchievements_toContext() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date().addingTimeInterval(-86400 * 3),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let logs = makeConsecutiveLogs(days: 3, context: context)

        AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        let fetchRequest = NSFetchRequest<UnlockedAchievement>(entityName: "UnlockedAchievement")
        let fetched = try context.fetch(fetchRequest)
        #expect(fetched.count >= 2) // 至少 1 天和 3 天两个
    }

    // MARK: - 减量类徽章

    @Test func awards_streak1Day_whenTodayBelowBaseline() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let today = Calendar.current.startOfDay(for: Date())
        let log = SmokingLog(context: context, date: today, count: 10) // 10 < 20 基准

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: [log], context: context)

        #expect(badges.map(\.id).contains("streak_1_day"))
    }

    @Test func awards_streak3Days_whenThreeConsecutiveDaysBelow() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let logs = makeConsecutiveLogs(days: 3, context: context)

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        #expect(badges.map(\.id).contains("streak_3_days"))
    }

    @Test func noStreak3Days_whenOnlyOneDayBelow() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let today = Calendar.current.startOfDay(for: Date())
        let log = SmokingLog(context: context, date: today, count: 10) // 只有今天一天

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: [log], context: context)

        #expect(!badges.map(\.id).contains("streak_3_days"))
    }

    @Test func awards_reductionHalf_whenSevenDayAvgBelowHalf() throws {
        let context = makeContext()
        let profile = UserProfile(
            context: context,
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let cal = Calendar.current
        // 近 7 天均抽 8 支（< 20 × 50% = 10）
        var logs: [SmokingLog] = []
        for offset in 0..<7 {
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
            let log = SmokingLog(context: context, date: date, count: 8)
            log.baselineAtTime = 20
            logs.append(log)
        }

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        #expect(badges.map(\.id).contains("reduction_half"))
    }
}
