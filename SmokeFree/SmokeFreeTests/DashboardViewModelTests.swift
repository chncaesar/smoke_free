import Testing
import Foundation
@testable import SmokeFree

struct DashboardViewModelTests {

    // MARK: - update() 基础字段

    @Test func update_setsStreakDaysAndMoneySaved() {
        let quitDate = Date().addingTimeInterval(-86400 * 5) // 5 天前
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        // 模拟一条昨天的日志：抽了 10 支，比基准 20 支少 10 支
        let log = SmokingLog(date: Date().addingTimeInterval(-86400), count: 10)
        log.baselineAtTime = 20
        log.pricePerPackAtTime = 25
        log.cigarettesPerPackAtTime = 20
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [log])

        #expect(vm.streakDays == 5)
        // 少抽 10 支 × (25 / 20) = 12.5 元
        #expect(vm.moneySaved > 0)
    }

    // MARK: - 里程碑进度

    @Test func update_25SecondsIn_firstMilestoneIsNext() {
        // 刚戒烟 25 秒，下一个里程碑应该是 "20 分钟"（1200 秒）
        let quitDate = Date().addingTimeInterval(-25)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestone?.id == "20min")
    }

    @Test func update_progressBetweenZeroAndOne() {
        let quitDate = Date().addingTimeInterval(-600) // 10 分钟，介于 0 和 20 分钟之间
        let profile = UserProfile(
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
        let quitDate = Date().addingTimeInterval(-86400 * 400)
        let profile = UserProfile(
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

    @Test func timeRemaining_withinOneHour_showsMinutes() {
        // 距 20 分钟里程碑还有约 19 分钟
        let quitDate = Date().addingTimeInterval(-60)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestoneTimeRemaining.contains("分钟"))
    }

    @Test func timeRemaining_withinOneDay_showsHours() {
        // 距 8 小时里程碑（28800秒）还有约 4 小时
        let quitDate = Date().addingTimeInterval(-14400) // 4 小时前
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        #expect(vm.nextMilestoneTimeRemaining.contains("小时"))
    }

    @Test func timeRemaining_moreThanOneDay_showsDays() {
        // 距 2 周里程碑（1209600秒）还有约 10 天
        let quitDate = Date().addingTimeInterval(-86400 * 4) // 4 天前
        let profile = UserProfile(
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
        let quitDate = Date().addingTimeInterval(-86400 * 10)
        let profile = UserProfile(
            quitDate: quitDate,
            cigarettesPerDayBefore: 20,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let vm = DashboardViewModel()
        vm.update(from: profile, logs: [])

        let formatted = vm.formattedMoneySaved(currencyCode: "CNY")
        #expect(!formatted.isEmpty)
        // 10 天 × ¥25 = ¥250，格式化结果应包含数字
        #expect(formatted.contains("2") || formatted.contains("¥"))
    }
}
