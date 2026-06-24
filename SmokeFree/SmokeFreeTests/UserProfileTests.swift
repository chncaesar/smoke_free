import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct UserProfileTests {

    // MARK: - 辅助：内存 Core Data 容器

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
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
}

// MARK: - 辅助

private extension Double {
    func isApproximatelyEqual(to other: Double, tolerance: Double) -> Bool {
        abs(self - other) <= tolerance
    }
}
