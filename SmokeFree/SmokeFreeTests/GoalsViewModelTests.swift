import Testing
import Foundation
import CoreData
@testable import SmokeFree

struct GoalsViewModelTests {

    private func makeContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "SmokeFree", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions.first!.type = NSInMemoryStoreType
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }

    // MARK: - checkCompletion — 按天数

    @Test func checkCompletion_byDays_marksGoalComplete() {
        let context = makeContext()
        let goal = Goal(context: context, title: "坚持一周", reward: "买本书", targetDays: 7)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 7, moneySaved: 0)

        #expect(goal.isCompleted)
        #expect(goal.completedAt != nil)
    }

    @Test func checkCompletion_byDays_savesCompletedGoal() throws {
        let context = makeContext()
        let goal = Goal(context: context, title: "坚持一天", reward: "散步", targetDays: 1)
        try context.save()
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 1, moneySaved: 0)

        #expect(goal.isCompleted)
        #expect(context.hasChanges == false)
    }

    @Test func checkCompletion_byDays_doesNotComplete_whenBelowTarget() {
        let context = makeContext()
        let goal = Goal(context: context, title: "坚持一周", reward: "买本书", targetDays: 7)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 6, moneySaved: 0)

        #expect(!goal.isCompleted)
        #expect(goal.completedAt == nil)
    }

    @Test func checkCompletion_byDays_doesNotCompleteFromTodayInProgressLog() {
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
        let goal = Goal(context: context, title: "控烟第一天", reward: "散步", targetDays: 1)
        let vm = GoalsViewModel()

        vm.checkCompletion(profile: profile, goals: [goal], logs: [log], purchases: [])

        #expect(!goal.isCompleted)
        #expect(goal.completedAt == nil)
    }

    @Test func checkCompletion_byDays_completesFromYesterdayBelowBaseline() {
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
        let goal = Goal(context: context, title: "控烟第一天", reward: "散步", targetDays: 1)
        let vm = GoalsViewModel()

        vm.checkCompletion(profile: profile, goals: [goal], logs: [log], purchases: [])

        #expect(goal.isCompleted)
        #expect(goal.completedAt != nil)
    }

    // MARK: - checkCompletion — 按金额

    @Test func checkCompletion_byMoney_marksGoalComplete() {
        let context = makeContext()
        let goal = Goal(context: context, title: "存够电影钱", reward: "看电影", targetDays: 999, targetMoneySaved: 50.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 0, moneySaved: 50.0)

        #expect(goal.isCompleted)
    }

    @Test func checkCompletion_byMoney_doesNotComplete_whenBelowTarget() {
        let context = makeContext()
        let goal = Goal(context: context, title: "存够电影钱", reward: "看电影", targetDays: 999, targetMoneySaved: 50.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 0, moneySaved: 49.9)

        #expect(!goal.isCompleted)
    }

    @Test func checkCompletion_byMoney_doesNotCompleteFromTodayInProgressSavings() {
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
        let goal = Goal(context: context, title: "存够钱", reward: "奖励", targetDays: 999, targetMoneySaved: 21.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(profile: profile, goals: [goal], logs: [yesterdayLog, todayLog], purchases: [])

        #expect(!goal.isCompleted)
        #expect(goal.completedAt == nil)
    }

    // MARK: - checkCompletion — 已完成目标不再处理

    @Test func checkCompletion_skips_alreadyCompletedGoals() {
        let context = makeContext()
        let goal = Goal(context: context, title: "已完成", reward: "奖励", targetDays: 1)
        goal.isCompleted = true
        let originalDate = Date().addingTimeInterval(-3600)
        goal.completedAt = originalDate
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 100, moneySaved: 1000)

        // completedAt 不应被更新
        #expect(abs((goal.completedAt ?? Date()).timeIntervalSince(originalDate)) < 1)
    }

    // MARK: - activeGoals / completedGoals

    @Test func activeGoals_returnsOnlyIncomplete_sortedBySortOrder() {
        let context = makeContext()
        let g1 = Goal(context: context, title: "目标A", reward: "奖励A", targetDays: 7, sortOrder: 2)
        let g2 = Goal(context: context, title: "目标B", reward: "奖励B", targetDays: 14, sortOrder: 1)
        let g3 = Goal(context: context, title: "目标C", reward: "奖励C", targetDays: 30)
        g3.isCompleted = true

        let vm = GoalsViewModel()
        let active = vm.activeGoals(from: [g1, g2, g3])

        #expect(active.count == 2)
        #expect(active[0].title == "目标B") // sortOrder: 1 在前
        #expect(active[1].title == "目标A") // sortOrder: 2 在后
    }

    @Test func completedGoals_returnsOnlyCompleted_sortedByCompletedAtDesc() {
        let context = makeContext()
        let g1 = Goal(context: context, title: "早完成", reward: "奖励", targetDays: 1)
        g1.isCompleted = true
        g1.completedAt = Date().addingTimeInterval(-7200) // 2 小时前

        let g2 = Goal(context: context, title: "晚完成", reward: "奖励", targetDays: 3)
        g2.isCompleted = true
        g2.completedAt = Date().addingTimeInterval(-3600) // 1 小时前

        let g3 = Goal(context: context, title: "未完成", reward: "奖励", targetDays: 7)

        let vm = GoalsViewModel()
        let completed = vm.completedGoals(from: [g1, g2, g3])

        #expect(completed.count == 2)
        #expect(completed[0].title == "晚完成") // 最近完成的在前
        #expect(completed[1].title == "早完成")
    }

    // MARK: - progress display

    @Test func progressText_byDays_doesNotCountTodayInProgressDay() {
        let context = makeContext()
        let today = Calendar.current.startOfDay(for: Date())
        let profile = UserProfile(
            context: context,
            quitDate: today,
            cigarettesPerDayBefore: 15,
            pricePerPack: 25,
            cigarettesPerPack: 20
        )
        let goal = Goal(context: context, title: "控烟三天", reward: "", targetDays: 3)
        let vm = GoalsViewModel()

        let value = vm.progressValue(goal: goal, profile: profile, logs: [], purchases: [])
        let text = vm.progressText(goal: goal, profile: profile, logs: [], purchases: [])

        #expect(value == 0)
        #expect(text == "0 / 3 天")
    }

    @Test func progressText_byMoney_doesNotCountTodayInProgressSavings() {
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
        let goal = Goal(context: context, title: "存够钱", reward: "", targetDays: 999, targetMoneySaved: 21)
        let vm = GoalsViewModel()

        let value = vm.progressValue(goal: goal, profile: profile, logs: [yesterdayLog, todayLog], purchases: [])
        let text = vm.progressText(goal: goal, profile: profile, logs: [yesterdayLog, todayLog], purchases: [])

        #expect(abs(value - (20.0 / 21.0)) < 0.0001)
        #expect(text == "¥20 / ¥21")
    }

    // MARK: - isFormValid

    @Test func isFormValid_true_whenTitleAndRewardNonEmpty() {
        let vm = GoalsViewModel()
        vm.newTitle = "我的目标"
        vm.newReward = "我的奖励"

        #expect(vm.isFormValid)
    }

    @Test func isFormValid_false_whenTitleEmpty() {
        let vm = GoalsViewModel()
        vm.newTitle = "   "
        vm.newReward = "我的奖励"

        #expect(!vm.isFormValid)
    }

    @Test func isFormValid_true_whenRewardEmpty() {
        let vm = GoalsViewModel()
        vm.newTitle = "我的目标"
        vm.newReward = ""

        #expect(vm.isFormValid)
    }

    @Test func isFormValid_false_whenMoneyTargetEnabledWithoutAmount() {
        let vm = GoalsViewModel()
        vm.newTitle = "我的目标"
        vm.newReward = "奖励"
        vm.useMoneyTarget = true
        vm.newTargetMoney = nil

        #expect(!vm.isFormValid)
    }

    @Test func isFormValid_false_whenMoneyTargetEnabledWithZeroAmount() {
        let vm = GoalsViewModel()
        vm.newTitle = "我的目标"
        vm.newReward = "奖励"
        vm.useMoneyTarget = true
        vm.newTargetMoney = 0

        #expect(!vm.isFormValid)
    }

    // MARK: - checkCompletion — 同时满足天数和金额

    @Test func checkCompletion_eitherConditionSuffices() {
        // 只有金额条件满足（天数未达到）
        let context = makeContext()
        let goal = Goal(context: context, title: "复合目标", reward: "奖励", targetDays: 30, targetMoneySaved: 50.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 5, moneySaved: 100.0)

        #expect(goal.isCompleted)
    }
}
