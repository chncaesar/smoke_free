import Foundation
import Combine
import CoreData

final class GoalsViewModel: ObservableObject {
    @Published var showAddSheet = false
    @Published var showEditSheet = false
    @Published private(set) var editingGoal: Goal? = nil
    @Published var hasActiveMoneyGoal = false

    // 新目标表单
    @Published var newTitle = ""
    @Published var newReward = ""
    @Published var newTargetDays = 7
    @Published var newTargetMoney: Double? = nil
    @Published var useMoneyTarget = false

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
            if goal.targetMoneySaved > 0 {
                achieved = moneySaved >= goal.targetMoneySaved
            } else {
                achieved = streakDays >= goal.targetDays
            }
            if achieved {
                goal.isCompleted = true
                goal.completedAt = Date()
            }
        }
    }

    func addGoal(context: NSManagedObjectContext, sortOrder: Int) {
        let goal = Goal(
            context: context,
            title: newTitle.trimmingCharacters(in: .whitespaces),
            reward: newReward.trimmingCharacters(in: .whitespaces),
            targetDays: newTargetDays,
            targetMoneySaved: useMoneyTarget ? (newTargetMoney ?? 0) : 0,
            sortOrder: sortOrder
        )
        context.insert(goal)
        resetForm()
        showAddSheet = false
    }

    func startEditing(_ goal: Goal) {
        editingGoal = goal
        newTitle = goal.title ?? ""
        newReward = goal.reward ?? ""
        newTargetDays = Int(goal.targetDays)
        newTargetMoney = goal.targetMoneySaved
        useMoneyTarget = goal.targetMoneySaved > 0
        showEditSheet = true
    }

    func saveEdit() {
        guard let goal = editingGoal else { return }
        goal.title = newTitle.trimmingCharacters(in: .whitespaces)
        goal.reward = newReward.trimmingCharacters(in: .whitespaces)
        goal.targetDays = Int32(newTargetDays)
        goal.targetMoneySaved = useMoneyTarget ? (newTargetMoney ?? 0) : 0
        editingGoal = nil
        resetForm()
        showEditSheet = false
    }

    func deleteGoal(_ goal: Goal, context: NSManagedObjectContext) {
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
