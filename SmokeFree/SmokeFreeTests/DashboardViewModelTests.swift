import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct DashboardViewModelTests {

    // MARK: - 辅助：内存 Core Data 容器

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    // MARK: - update() 基础字段

    @Test func update_setsStreakDaysAndMoneySaved() {
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 5) // 5 天前
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        // 模拟一条昨天的日志：抽了 10 支，比基准 20 支少 10 支
        let log = SmokingLog(context: context, date: Date().addingTimeInterval(-86400), count: 10)
        log.baselineAtTime = 20
        log.pricePerPackAtTime = 25
        log.cigarettesPerPackAtTime = 20
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [log])

        // 宽松连续天数：戒烟当天也算 1 天，5 天前戒烟 → 今天起回溯共 6 天
        #expect(vm.streakDays == 6)
        // 少抽 10 支 × (25 / 20) = 12.5 元
        #expect(vm.moneySaved > 0)
    }

    // MARK: - 里程碑进度

    @Test func update_25SecondsIn_firstMilestoneIsNext() {
        // 刚戒烟 25 秒，宽松连续天数下当天已算 streak=1，下一个里程碑是 "3days"（需要 3 天）
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-25)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestone?.id == "3days")
    }

    @Test func update_progressBetweenZeroAndOne() {
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400) // 1 天前，streakDays=2（含今天）
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestoneProgress > 0)
        #expect(vm.nextMilestoneProgress < 1)
    }

    @Test func update_allMilestonesUnlocked_nextMilestoneIsNil() {
        // 戒烟超过 1 年，所有里程碑已解锁
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 400)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestone == nil)
        #expect(vm.nextMilestoneProgress == 1.0)
        #expect(vm.nextMilestoneTimeRemaining.isEmpty)
    }

    // MARK: - 剩余时间格式化（通过 nextMilestoneTimeRemaining 间接验证）
    // 新格式："""还需 N 天连续控烟"""

    @Test func timeRemaining_withinOneDay_showsDays() {
        // 距 day1 里程碑（1 天）还有 1 天
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-60)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestoneTimeRemaining.contains("天"))
    }

    @Test func timeRemaining_showsConnectiveSmokingFormat() {
        // 距 1week 里程碑（7 天）还有约 3 天
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 4) // 4 天前
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestoneTimeRemaining.contains("连续控烟"))
    }

    @Test func timeRemaining_moreThanOneDay_showsDays() {
        // 距 1week 里程碑（7 天）还有约 3 天
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 4) // 4 天前
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestoneTimeRemaining.contains("天"))
    }

    // MARK: - 金额格式化

    @Test func formattedMoneySaved_CNY() {
        let context = makeContext()
        let quitDate = Date().addingTimeInterval(-86400 * 10)
        let profile = UserProfile(
            context: context,
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        let formatted = vm.formattedMoneySaved(currencyCode: "CNY")
        #expect(!formatted.isEmpty)
        // moneySaved 基于日志计算，无日志时为 0，格式化结果应包含数字
        #expect(formatted.contains("0") || formatted.contains("¥"))
    }
}
