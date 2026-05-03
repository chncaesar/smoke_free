import Testing
import Foundation
import SwiftData
@testable import SmokeFree

struct GoalsViewModelTests {

    // MARK: - checkCompletion — 按天数

    @Test func checkCompletion_byDays_marksGoalComplete() {
        let goal = Goal(title: "坚持一周", reward: "买本书", targetDays: 7)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 7, moneySaved: 0)

        #expect(goal.isCompleted)
        #expect(goal.completedAt != nil)
    }

    @Test func checkCompletion_byDays_doesNotComplete_whenBelowTarget() {
        let goal = Goal(title: "坚持一周", reward: "买本书", targetDays: 7)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 6, moneySaved: 0)

        #expect(!goal.isCompleted)
        #expect(goal.completedAt == nil)
    }

    // MARK: - checkCompletion — 按金额

    @Test func checkCompletion_byMoney_marksGoalComplete() {
        let goal = Goal(title: "存够电影钱", reward: "看电影", targetDays: 999, targetMoneySaved: 50.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 0, moneySaved: 50.0)

        #expect(goal.isCompleted)
    }

    @Test func checkCompletion_byMoney_doesNotComplete_whenBelowTarget() {
        let goal = Goal(title: "存够电影钱", reward: "看电影", targetDays: 999, targetMoneySaved: 50.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 0, moneySaved: 49.9)

        #expect(!goal.isCompleted)
    }

    // MARK: - checkCompletion — 已完成目标不再处理

    @Test func checkCompletion_skips_alreadyCompletedGoals() {
        let goal = Goal(title: "已完成", reward: "奖励", targetDays: 1)
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
        let g1 = Goal(title: "目标A", reward: "奖励A", targetDays: 7, sortOrder: 2)
        let g2 = Goal(title: "目标B", reward: "奖励B", targetDays: 14, sortOrder: 1)
        let g3 = Goal(title: "目标C", reward: "奖励C", targetDays: 30)
        g3.isCompleted = true

        let vm = GoalsViewModel()
        let active = vm.activeGoals(from: [g1, g2, g3])

        #expect(active.count == 2)
        #expect(active[0].title == "目标B") // sortOrder: 1 在前
        #expect(active[1].title == "目标A") // sortOrder: 2 在后
    }

    @Test func completedGoals_returnsOnlyCompleted_sortedByCompletedAtDesc() {
        let g1 = Goal(title: "早完成", reward: "奖励", targetDays: 1)
        g1.isCompleted = true
        g1.completedAt = Date().addingTimeInterval(-7200) // 2 小时前

        let g2 = Goal(title: "晚完成", reward: "奖励", targetDays: 3)
        g2.isCompleted = true
        g2.completedAt = Date().addingTimeInterval(-3600) // 1 小时前

        let g3 = Goal(title: "未完成", reward: "奖励", targetDays: 7)

        let vm = GoalsViewModel()
        let completed = vm.completedGoals(from: [g1, g2, g3])

        #expect(completed.count == 2)
        #expect(completed[0].title == "晚完成") // 最近完成的在前
        #expect(completed[1].title == "早完成")
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

    @Test func isFormValid_false_whenRewardEmpty() {
        let vm = GoalsViewModel()
        vm.newTitle = "我的目标"
        vm.newReward = ""

        #expect(!vm.isFormValid)
    }

    // MARK: - checkCompletion — 同时满足天数和金额

    @Test func checkCompletion_eitherConditionSuffices() {
        // 只有金额条件满足（天数未达到）
        let goal = Goal(title: "复合目标", reward: "奖励", targetDays: 30, targetMoneySaved: 50.0)
        let vm = GoalsViewModel()

        vm.checkCompletion(goals: [goal], streakDays: 5, moneySaved: 100.0)

        #expect(goal.isCompleted)
    }
}
