import SwiftUI
import CoreData
import UIKit

struct DashboardView: View {
    @FetchRequest(sortDescriptors: []) private var profiles: FetchedResults<UserProfile>
    @FetchRequest(sortDescriptors: [SortDescriptor(\SmokingLog.date, order: .reverse)]) private var logs: FetchedResults<SmokingLog>
    @FetchRequest(sortDescriptors: [SortDescriptor(\PurchaseRecord.date, order: .reverse)]) private var purchases: FetchedResults<PurchaseRecord>
    @Environment(\.managedObjectContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var vm = DashboardViewModel()

    private var profile: UserProfile? { profiles.first }
    private var todayLog: SmokingLog? {
        let today = Calendar.current.startOfDay(for: Date())
        return logs.first(where: { ($0.date ?? Date()) == today })
    }

    @State private var showEditBaseline = false
    @State private var showEditGoalSheet = false
    @State private var showShareSheet = false
    @State private var exportDirURL: URL?
    @State private var exportError: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if let profile {
                        StreakCardView(streakDays: vm.streakDays)

                        ReductionProgressCard(vm: vm)

                        MoneySavedCardView(
                            moneySaved: vm.moneySaved,
                            currencyCode: profile.currencyCode ?? "CNY"
                        )

                        if let milestone = vm.nextMilestone {
                            HealthStatusCardView(
                                milestone: milestone,
                                progress: vm.nextMilestoneProgress,
                                timeRemaining: vm.nextMilestoneTimeRemaining
                            )
                        }

                        SmokingCostCard(vm: vm, profile: profile) {
                            showEditGoalSheet = true
                        }

                    } else {
                        VStack(spacing: 8) {
                            Spacer().frame(height: 40)
                            Image(systemName: "lungs")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("完成引导以开始")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("请先完成初始设置")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { exportData() } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button { showEditBaseline = true } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditBaseline) {
                if let profile {
                    EditBaselineView(profile: profile, logs: Array(logs), context: context) {
                        updateVM()
                    }
                }
            }
            .sheet(isPresented: $showEditGoalSheet) {
                if let profile {
                    EditGoalView(profile: profile) { updateVM() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportDirURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("导出失败", isPresented: Binding<Bool>(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .onAppear { updateVM() }
            .onChange(of: SmokingLog.changeToken(for: logs)) { _ in updateVM() }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    updateVM()
                    vm.ensureTodayReminderIfNeeded(hasLoggedToday: todayLog != nil)
                }
                if newPhase == .background { try? context.save() }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func updateVM() {
        guard let profile else { return }
        vm.update(from: profile, logs: Array(logs), purchases: Array(purchases))
        vm.updateReduction(todayLog: todayLog, profile: profile, purchases: Array(purchases), logs: Array(logs))
        vm.updateCost(profile: profile, logs: Array(logs), purchases: Array(purchases))
        vm.processAfterUpdate(profile: profile, logs: Array(logs), purchases: Array(purchases), context: context)
    }

    private func exportData() {
        do {
            exportDirURL = try vm.exportData(context: context)
            showShareSheet = true
        } catch {
            exportError = "导出失败，请稍后重试。"
        }
    }
}

// MARK: - 子视图

private struct ReductionProgressCard: View {
    let vm: DashboardViewModel

    private let equivalents: [(name: String, price: Double, icon: String)] = [
        ("矿泉水", 2,  "drop.fill"),
        ("公交票", 2,  "bus.fill"),
        ("包子",   3,  "takeoutbag.and.cup.and.straw.fill"),
        ("奶茶",   18, "cup.and.saucer.fill"),
        ("麦当劳", 35, "fork.knife"),
    ]

    private var subtitleText: String {
        guard vm.baselineCount > 0 else { return "设定基准用量后显示" }
        if vm.todayCount < 0 { return "今天还没记录" }
        let diff = vm.baselineCount - vm.todayCount
        if diff > 0 {
            let pct = Int(vm.reductionPercent * 100)
            return "比基准少了 \(diff) 支（减少 \(pct)%）"
        } else if diff == 0 {
            return "与基准持平，明天再少一支！"
        } else {
            return "比基准多了 \(abs(diff)) 支，明天继续努力"
        }
    }

    /// 今日节省金额对应的最佳小额等价物
    private var equivalentText: String? {
        guard vm.todaySavings > 0 else { return nil }
        // 从最贵的往下找，返回第一个 count ≥ 1 的
        for eq in equivalents.reversed() {
            let count = Int(vm.todaySavings / eq.price)
            if count >= 1 {
                return "省了 ¥\(String(format: "%.1f", vm.todaySavings))，相当于 \(count) \(unitLabel(eq.name))\(eq.name)"
            }
        }
        // 不够买任何东西时只显示金额
        return "今日省了 ¥\(String(format: "%.2f", vm.todaySavings))"
    }

    private func unitLabel(_ name: String) -> String {
        switch name {
        case "矿泉水", "奶茶": return "瓶"
        case "包子": return "个"
        case "公交票": return "张"
        default: return "顿"
        }
    }

    var body: some View {
        CardView {
            HStack(spacing: 16) {
                ProgressRingView(
                    progress: vm.reductionPercent,
                    size: 56,
                    color: vm.reductionPercent > 0 ? .orange : .secondary
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("今日用量")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.todayCount >= 0 {
                        Text("\(vm.todayCount) 支")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    } else {
                        Text("尚未记录")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(vm.reductionPercent > 0 ? .orange : .secondary)

                    if let eq = equivalentText {
                        Text(eq)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
        }
    }
}

private struct StreakCardView: View {
    let streakDays: Int

    var body: some View {
        CardView {
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("连续控烟")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(streakDays) 天")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
        }
    }
}

private struct MoneySavedCardView: View {
    let moneySaved: Double
    let currencyCode: String

    private var formattedAmount: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: moneySaved)) ?? "¥\(String(format: "%.1f", moneySaved))"
    }

    private var isNegative: Bool { moneySaved < 0 }

    var body: some View {
        CardView {
            HStack(spacing: 16) {
                Image(systemName: isNegative ? "arrow.down.circle.fill" : "banknote.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(isNegative ? .red : .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isNegative ? "已超额" : "已节省")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formattedAmount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(isNegative ? .red : .green)
                }
                Spacer()
            }
        }
    }
}

// MARK: - 修改基准 Sheet

private struct EditBaselineView: View {
    let profile: UserProfile
    let logs: [SmokingLog]
    let context: NSManagedObjectContext
    let onSave: () -> Void

    @StateObject private var vm = DashboardViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var newBaseline: Int
    @State private var newPrice: Double
    @State private var newPerPack: Int

    init(profile: UserProfile, logs: [SmokingLog], context: NSManagedObjectContext, onSave: @escaping () -> Void) {
        self.profile = profile
        self.logs = logs
        self.context = context
        self.onSave = onSave
        _newBaseline = State(initialValue: Int(profile.cigarettesPerDayBefore))
        _newPrice = State(initialValue: profile.pricePerPack)
        _newPerPack = State(initialValue: Int(profile.cigarettesPerPack))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("每日基准用量") {
                    Stepper("每天 \(newBaseline) 支", value: $newBaseline, in: 1...200)
                }
                Section("烟价") {
                    HStack {
                        Text("每包价格")
                        Spacer()
                        TextField("25", value: $newPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("元")
                    }
                    Stepper("每包 \(newPerPack) 支", value: $newPerPack, in: 1...100)
                }
                Section {
                    Text("修改后，新记录将以新基准计算进度和节省金额；已有记录保留原基准不受影响。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("修改基准")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        applyChanges()
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func applyChanges() {
        vm.saveBaselineChanges(
            profile: profile,
            logs: logs,
            context: context,
            newBaseline: newBaseline,
            newPrice: newPrice,
            newPerPack: newPerPack
        )
    }
}

private struct SmokingCostCard: View {
    let vm: DashboardViewModel
    let profile: UserProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("烟草开销", systemImage: "dollarsign.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text("按现在用量，每年花费 \(vm.formatCurrency(vm.annualBaselineCost, currencyCode: profile.currencyCode ?? "CNY"))")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(vm.formattedYearsToGoal()) 后")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                        Text("抽掉一辆「\(profile.goalName ?? "")」（\(vm.formatCurrency(profile.goalAmount, currencyCode: profile.currencyCode ?? "CNY"))）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                    Text("迄今实际花费：\(vm.formatCurrency(vm.totalSpentOnSmokes, currencyCode: profile.currencyCode ?? "CNY"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HealthStatusCardView: View {
    let milestone: HealthMilestone
    let progress: Double
    let timeRemaining: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("下个健康里程碑")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    ProgressRingView(progress: progress, size: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: milestone.iconName)
                                .foregroundStyle(.green)
                            Text(milestone.title)
                                .font(.headline)
                        }
                        Text(milestone.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !timeRemaining.isEmpty {
                            Text(timeRemaining)
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
