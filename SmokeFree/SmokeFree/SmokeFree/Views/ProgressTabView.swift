import SwiftUI
import SwiftData

/// 进度 Tab 的容器视图，聚合趋势图表、支出统计、健康时间线、成就徽章
struct ProgressTabView: View {
    @Query private var profiles: [UserProfile]
    @Query private var purchases: [PurchaseRecord]
    @Query(sort: \SmokingLog.date, order: .reverse) private var logs: [SmokingLog]
    @Query private var goals: [Goal]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                if let profile {
                    Section {
                        ExpenseStatsView(
                            profile: profile,
                            logs: Array(logs),
                            moneyGoals: goals.filter { $0.targetMoneySaved != nil }
                        )
                    }
                }

                Section {
                    NavigationLink("趋势图表") { TrendsView() }
                    NavigationLink("健康恢复时间线") { HealthTimelineView() }
                    NavigationLink("成就徽章") { AchievementsView() }
                }
            }
            .navigationTitle("进度")
        }
    }
}

// MARK: - 支出对比

private struct ExpenseStatsView: View {
    let profile: UserProfile
    let logs: [SmokingLog]
    var moneyGoals: [Goal] = []

    private let comparisons: [(name: String, price: Double, icon: String)] = [
        ("麦当劳", 35, "fork.knife"),
        ("电影票", 60, "film"),
        ("新书", 50, "book.fill"),
        ("AirPods", 1299, "airpodspro"),
        ("iPhone", 5999, "iphone"),
    ]

    private var totalSaved: Double { profile.moneySaved(logs: logs) }

    private func formattedSaved() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = profile.currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: totalSaved))
            ?? "\(String(format: "%.2f", totalSaved))"
    }

    private var bestComparison: (name: String, count: Int, icon: String)? {
        for comp in comparisons.reversed() {
            let count = Int(totalSaved / comp.price)
            if count >= 1 { return (comp.name, count, comp.icon) }
        }
        return (comparisons[0].name, 0, comparisons[0].icon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("已节省金额")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formattedSaved())
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            if let comp = bestComparison {
                if comp.count > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: comp.icon)
                            .foregroundStyle(.orange)
                        Text("够买 \(comp.count) 顿\(comp.name)")
                            .font(.subheadline)
                    }
                } else {
                    Text("继续加油，节省更多！")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !moneyGoals.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                ForEach(moneyGoals) { goal in
                    if let target = goal.targetMoneySaved {
                        MoneyGoalProgressRow(
                            goal: goal,
                            current: totalSaved,
                            target: target
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 节省金额目标进度行

private struct MoneyGoalProgressRow: View {
    let goal: Goal
    let current: Double
    let target: Double

    private var progress: Double { min(current / target, 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.title)
                    .font(.subheadline)
                Spacer()
                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: progress)
                .tint(goal.isCompleted ? .green : .orange)
            HStack {
                Text("¥\(String(format: "%.0f", min(current, target))) / ¥\(String(format: "%.0f", target))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !goal.isCompleted {
                    Spacer()
                    Text("还差 ¥\(String(format: "%.0f", max(target - current, 0)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
