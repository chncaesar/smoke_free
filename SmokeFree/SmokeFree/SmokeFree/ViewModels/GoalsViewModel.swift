import Foundation
import SwiftData

@Observable
final class GoalsViewModel {
    var showAddSheet = false
    var showEditSheet = false
    private(set) var editingGoal: Goal? = nil
    var hasActiveMoneyGoal = false

    // 新目标表单
    var newTitle = ""
    var newReward = ""
    var newTargetDays = 7
    var newTargetMoney: Double? = nil
    var useMoneyTarget = false

    var isFormValid: Bool {
        !newTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newReward.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func activeGoals(from goals: [Goal]) -> [Goal] {
        goals.filter { !$0.isCompleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func completedGoals(from goals: [Goal]) -> [Goal] {
        goals.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func checkCompletion(goals: [Goal], streakDays: Int, moneySaved: Double) {
        for goal in goals where !goal.isCompleted {
            let achieved: Bool
            if let target = goal.targetMoneySaved {
                achieved = moneySaved >= target
            } else {
                achieved = streakDays >= goal.targetDays
            }
            if achieved {
                goal.isCompleted = true
                goal.completedAt = Date()
            }
        }
    }

    func addGoal(context: ModelContext, sortOrder: Int) {
        let goal = Goal(
            title: newTitle.trimmingCharacters(in: .whitespaces),
            reward: newReward.trimmingCharacters(in: .whitespaces),
            targetDays: newTargetDays,
            targetMoneySaved: useMoneyTarget ? newTargetMoney : nil,
            sortOrder: sortOrder
        )
        context.insert(goal)
        resetForm()
        showAddSheet = false
    }

    func startEditing(_ goal: Goal) {
        editingGoal = goal
        newTitle = goal.title
        newReward = goal.reward
        newTargetDays = goal.targetDays
        newTargetMoney = goal.targetMoneySaved
        useMoneyTarget = goal.targetMoneySaved != nil
        showEditSheet = true
    }

    func saveEdit() {
        guard let goal = editingGoal else { return }
        goal.title = newTitle.trimmingCharacters(in: .whitespaces)
        goal.reward = newReward.trimmingCharacters(in: .whitespaces)
        goal.targetDays = newTargetDays
        goal.targetMoneySaved = useMoneyTarget ? newTargetMoney : nil
        editingGoal = nil
        resetForm()
        showEditSheet = false
    }

    func deleteGoal(_ goal: Goal, context: ModelContext) {
        context.delete(goal)
    }

    private func resetForm() {
        newTitle = ""
        newReward = ""
        newTargetDays = 7
        newTargetMoney = nil
        useMoneyTarget = false
    }
}
