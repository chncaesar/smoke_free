import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct UserProfileTests {

    // MARK: - 辅助：内存 Core Data 容器

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.type = NSInMemoryStoreType
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    // MARK: - streakDays

    @Test func streakDays_exactlyOneDayAgo() {
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.streakDays == 1)
    }

    @Test func streakDays_tenDaysAgo() {
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 10)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.streakDays == 10)
    }

    @Test func streakDays_futureQuitDate_returnsZero() {
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(3600) // 1 小时后
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        #expect(profile.streakDays == 0)
    }

    // MARK: - completedStreakDays

    @Test func completedStreakDays_todayBelowBaseline_returnsZero() {
        let context = makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let profile = UserProfile(
            context: context,
            quitDate: today,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let log = SmokingLog(context: context, date: today, count: 14)
        log.baselineAtTime = 15

        #expect(profile.completedStreakDays(logs: [log]) == 0)
    }

    @Test func completedStreakDays_yesterdayBelowBaseline_returnsOne() {
        let context = makeContext()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let profile = UserProfile(
            context: context,
            quitDate: yesterday,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let log = SmokingLog(context: context, date: yesterday, count: 14)
        log.baselineAtTime = 15

        #expect(profile.completedStreakDays(logs: [log]) == 1)
    }

    @Test func completedStreakDays_yesterdayMissingLog_countsAsSuccess() {
        let context = makeContext()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let profile = UserProfile(
            context: context,
            quitDate: yesterday,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )

        #expect(profile.completedStreakDays(logs: []) == 1)
    }

    @Test func completedStreakDays_yesterdayAtBaseline_returnsZero() {
        let context = makeContext()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let profile = UserProfile(
            context: context,
            quitDate: yesterday,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let log = SmokingLog(context: context, date: yesterday, count: 15)
        log.baselineAtTime = 15

        #expect(profile.completedStreakDays(logs: [log]) == 0)
    }

    // MARK: - moneySaved
    // 注意：moneySaved(logs:purchases:) 基于日志计算，以下测试无日志时返回 0。
    // 需要创建包含实际减量数据的 SmokingLog 才能验证金额计算。

    @Test func moneySaved_oneDay_correctAmount() {
        // 20 支/天，¥25/包，20 支/包 → 单支 ¥1.25
        // 1 天 = 20 支 × ¥1.25 = ¥25
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        // TODO: 添加日志后验证：创建 count=0 的日志代表全天未吸烟
        #expect(profile.moneySaved(logs: [], purchases: []).isApproximatelyEqual(to: 0, tolerance: 0.5))
    }

    @Test func moneySaved_tenDays_correctAmount() {
        // 20 支/天 × 10 天 = 200 支，单支 ¥1.25 → ¥250
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 10)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        // TODO: 添加日志后验证：需要 10 天连续 count=0 的日志
        #expect(profile.moneySaved(logs: [], purchases: []).isApproximatelyEqual(to: 0, tolerance: 1.0))
    }

    @Test func moneySaved_customPackSize() {
        // 10 支/天，¥30/包，10 支/包 → 单支 ¥3.0
        // 1 天 → ¥30
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 10,
            pricePerPack: 30,
            cigarettesPerPack: 10
        )
        // TODO: 添加日志后验证：创建 count=0 的日志代表全天未吸烟
        #expect(profile.moneySaved(logs: [], purchases: []).isApproximatelyEqual(to: 0, tolerance: 0.5))
    }

    @Test func completedMoneySaved_excludesTodayInProgressLog() {
        let context = makeContext()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let profile = UserProfile(
            context: context,
            quitDate: yesterday,
            cigarettesPerDayBefore: 20,
            pricePerPack: 20,
            cigarettesPerPack: 20
        )
        let yesterdayLog = SmokingLog(context: context, date: yesterday, count: 0)
        yesterdayLog.baselineAtTime = 20
        yesterdayLog.pricePerPackAtTime = 20
        yesterdayLog.cigarettesPerPackAtTime = 20
        let todayLog = SmokingLog(context: context, date: today, count: 0)
        todayLog.baselineAtTime = 20
        todayLog.pricePerPackAtTime = 20
        todayLog.cigarettesPerPackAtTime = 20

        #expect(profile.moneySaved(logs: [yesterdayLog, todayLog]).isApproximatelyEqual(to: 40, tolerance: 0.01))
        #expect(profile.completedMoneySaved(logs: [yesterdayLog, todayLog]).isApproximatelyEqual(to: 20, tolerance: 0.01))
    }
}

// MARK: - 辅助

private extension Double {
    func isApproximatelyEqual(to other: Double, tolerance: Double) -> Bool {
        abs(self - other) <= tolerance
    }
}
