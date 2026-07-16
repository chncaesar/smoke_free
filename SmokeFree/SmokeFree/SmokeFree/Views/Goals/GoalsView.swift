import SwiftUI
import CoreData

struct GoalsView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\SmokingLog.date, order: .reverse)]) private var logs: FetchedResults<SmokingLog>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Goal.sortOrder)]) private var goals: FetchedResults<Goal>
    @FetchRequest(sortDescriptors: []) private var profiles: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [SortDescriptor(\PurchaseRecord.date, order: .reverse)]) private var purchases: FetchedResults<PurchaseRecord>
    @Environment(\.managedObjectContext) private var context
    @StateObject private var vm = GoalsViewModel()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationView {
            List {
                let active = vm.activeGoals(from: Array(goals))
                let completed = vm.completedGoals(from: Array(goals))

                if active.isEmpty && completed.isEmpty {
                    VStack(spacing: 8) {
                        Spacer().frame(height: 40)
                        Image(systemName: "target")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("还没有目标")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("点击右上角添加你的第一个目标")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if !active.isEmpty {
                    Section("进行中") {
                        ForEach(active, id: \.objectID) { goal in
                            GoalRowView(
                                goal: goal,
                                progressValue: vm.progressValue(
                                    goal: goal,
                                    profile: profile,
                                    logs: Array(logs),
                                    purchases: Array(purchases)
                                ),
                                progressText: vm.progressText(
                                    goal: goal,
                                    profile: profile,
                                    logs: Array(logs),
                                    purchases: Array(purchases)
                                )
                            )
                                .contentShape(Rectangle())
                                .onTapGesture { vm.startEditing(goal) }
                        }
                        .onDelete { indexSet in
                            for i in indexSet { vm.deleteGoal(active[i], context: context) }
                        }
                    }
                }

                if !completed.isEmpty {
                    Section("已完成") {
                        ForEach(completed, id: \.objectID) { goal in
                            GoalRowView(goal: goal, progressValue: 1.0, progressText: nil)
                        }
                    }
                }
            }
            .navigationTitle("目标")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $vm.showAddSheet) {
                AddGoalView(vm: vm, onAdd: {
                    vm.addGoal(context: context, sortOrder: goals.count)
                })
            }
            .sheet(isPresented: $vm.showEditSheet) {
                AddGoalView(vm: vm, onAdd: {
                    vm.saveEdit()
                }, isEditing: true)
            }
            .onAppear { checkCompletion() }
            .onChange(of: goals.count) { _ in checkCompletion() }
            .onChange(of: SmokingLog.changeToken(for: logs)) { _ in checkCompletion() }
        }
        .navigationViewStyle(.stack)
    }

    private func checkCompletion() {
        vm.checkCompletion(profile: profile, goals: Array(goals), logs: Array(logs), purchases: Array(purchases))
    }
}

// MARK: - 目标行

private struct GoalRowView: View {
    let goal: Goal
    let progressValue: Double
    let progressText: String?

    var body: some View {
        HStack(spacing: 12) {
            ProgressRingView(
                progress: progressValue,
                size: 44,
                lineWidth: 4,
                color: goal.isCompleted ? .green : .blue
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(goal.title ?? "")
                        .font(.headline)
                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(goal.reward ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let progressText {
                    Text(progressText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
