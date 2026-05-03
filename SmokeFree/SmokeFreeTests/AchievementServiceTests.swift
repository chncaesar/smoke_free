import Testing
import Foundation
import SwiftData
@testable import SmokeFree

struct AchievementServiceTests {

    // MARK: - 辅助：内存 ModelContext

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self, SmokingLog.self,
            PurchaseRecord.self, Goal.self, UnlockedAchievement.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    // MARK: - 按天数颁发

    @Test func awards_streak1Day_whenStreakIs1() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date().addingTimeInterval(-86400), // 1 天前
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)

        let ids = newBadges.map(\.id)
        #expect(ids.contains("streak_1_day"))
    }

    @Test func awards_multipleStreakBadges_when7DayStreak() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date().addingTimeInterval(-86400 * 7), // 7 天前
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)

        let ids = newBadges.map(\.id)
        #expect(ids.contains("streak_1_day"))
        #expect(ids.contains("streak_3_days"))
        #expect(ids.contains("streak_1_week"))
        #expect(!ids.contains("streak_1_month")) // 30 天未到
    }

    @Test func noAwards_whenStreakIsZero() throws {
        let context = try makeContext()
        let profile = UserProfile(
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
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date().addingTimeInterval(-86400),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        // 第一次颁发
        let first = AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)
        #expect(first.map(\.id).contains("streak_1_day"))

        // 第二次不应重复颁发
        let second = AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)
        #expect(!second.map(\.id).contains("streak_1_day"))
    }

    // MARK: - 全部解锁

    @Test func awards_allStreakBadges_when365DayStreak() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date().addingTimeInterval(-86400 * 365),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        let newBadges = AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)

        let ids = newBadges.map(\.id)
        let expectedIDs = ["streak_1_day", "streak_3_days", "streak_1_week",
                           "streak_1_month", "streak_3_months", "streak_6_months", "streak_1_year"]
        for expected in expectedIDs {
            #expect(ids.contains(expected), "应包含 \(expected)")
        }
    }

    // MARK: - 已解锁成就写入数据库

    @Test func persists_unlockedAchievements_toContext() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date().addingTimeInterval(-86400 * 3),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        AchievementService.evaluateAndAward(profile: profile, logs: [], context: context)

        let fetched = try context.fetch(FetchDescriptor<UnlockedAchievement>())
        #expect(fetched.count >= 2) // 至少 1 天和 3 天两个
    }

    // MARK: - 减量类徽章

    @Test func awards_reductionFirstDay_whenTodayBelowBaseline() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let today = Calendar.current.startOfDay(for: Date())
        let log = SmokingLog(date: today, count: 10) // 10 < 20 基准

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: [log], context: context)

        #expect(badges.map(\.id).contains("reduction_first_day"))
    }

    @Test func awards_reduction3Days_whenThreeConsecutiveDaysBelow() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let cal = Calendar.current
        let logs = (0..<3).map { offset -> SmokingLog in
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
            return SmokingLog(date: date, count: 10)
        }

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        #expect(badges.map(\.id).contains("reduction_3days"))
    }

    @Test func noReduction3Days_whenOnlyOneDayBelow() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let today = Calendar.current.startOfDay(for: Date())
        let log = SmokingLog(date: today, count: 10) // 只有今天一天

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: [log], context: context)

        #expect(!badges.map(\.id).contains("reduction_3days"))
    }

    @Test func awards_reductionHalf_whenSevenDayAvgBelowHalf() throws {
        let context = try makeContext()
        let profile = UserProfile(
            quitDate: Date(),
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let cal = Calendar.current
        // 近 7 天均抽 8 支（< 20 × 50% = 10）
        let logs = (0..<7).map { offset -> SmokingLog in
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
            return SmokingLog(date: date, count: 8)
        }

        let badges = AchievementService.evaluateAndAward(profile: profile, logs: logs, context: context)

        #expect(badges.map(\.id).contains("reduction_half"))
    }
}
